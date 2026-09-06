# Troubleshooting guide (Phase 10)

## Local development (`app/`)

**`pytest` fails with "no such table: notes"**
Happened once during this project's own Phase 2 validation. Cause: SQLite
`:memory:` databases are per-connection; FastAPI's `TestClient` runs the app
on a different thread than the test fixture, so without a shared connection
each thread got its own empty database. Fixed in `app/tests/conftest.py` by
using `poolclass=StaticPool` when creating the test engine — keep that if
you touch this fixture.

**`pip install` fails building `psycopg`/`pydantic-core` from source (Rust/linker errors)**
Happened during this project's own setup with a too-new Python (3.14 at the
time). Prebuilt wheels lag the newest CPython release. Fix: use a Python
version one or two minor releases behind latest (3.12 worked cleanly) for
the app's virtualenv, rather than trying to get a source build's toolchain
(Rust + MSVC linker on Windows) working.

## Docker

**Image build fails / `docker` not found**
This was never actually validated in this project's development
environment (no Docker on that machine — see PROGRESS.md Phase 3). If
`docker build app/` fails for you: check you're building from the repo
root with `app` as context (not from inside `app/`), and that
`app/.dockerignore` isn't excluding something the build needs (it excludes
`tests/`, `.venv/`, `*.db` — nothing the image needs at runtime).

## Terraform

**`terraform plan`/`apply` fails with `unable to build authorizer ... "az": executable file not found`**
Azure CLI isn't installed or you haven't run `az login`. The `azurerm`
provider's default authentication method shells out to `az` for your
session token. Install Azure CLI and run `az login` (or configure a service
principal / OIDC as in `docs/github-oidc-setup.md` for CI).

**`terraform apply` fails with a quota error on the AKS node pool**
This is the AD-005 risk materializing. Run `az vm list-usage --location
<region> -o table` and look at the `Total Regional vCPUs` (or the specific
`Standard BSv2 Family vCPUs` / relevant family) row's `CurrentValue` vs.
`Limit`. Free Trial subscriptions cannot request an increase — options are:
reduce node count/size further (not much room below `B2s`), delete other
compute in the subscription, or upgrade to Pay-As-You-Go (which can request
a quota increase).

**ACR/PostgreSQL name already taken**
Both need globally unique names; `random_string.suffix` in
`envs/dr-poc/main.tf` should make collisions unlikely but not impossible.
Re-run `terraform apply` (it will generate a new suffix only if the
resource hasn't been created yet — if a name collision happens mid-apply,
you may need to `terraform taint random_string.suffix` and re-plan).

## Kubernetes / Helm

**Pods stuck `Pending`**
On a single-node `Standard_B2s` cluster, this is almost always insufficient
CPU/memory left after system pods (CoreDNS, kube-proxy, CNI, metrics-server,
etc.). Check with `kubectl describe pod <pod>` for `Insufficient cpu` /
`Insufficient memory` events, and `kubectl top nodes` if metrics-server is
available. Fix: lower `resources.requests` in `helm/resilientops/values.yaml`
further, or accept that this single-node POC cluster has very little
headroom (a direct consequence of AD-005).

**`ImagePullBackOff`**
Usually one of: (a) the `AcrPull` role assignment hasn't propagated yet
(can take a couple of minutes after `terraform apply`), (b) `image.repository`
in the Helm values doesn't match `terraform output acr_login_server` exactly,
or (c) the tag doesn't exist in ACR yet — confirm with `az acr repository
show-tags --name <acr-name> --repository resilientops-backend`.

**`/readyz` returns 503**
The app can't reach its PostgreSQL server. Check: the `resilientops-db-credentials`
Secret exists in the right namespace and has the right connection string
(host, port 5432, `sslmode=require`); the PostgreSQL firewall rule allows
the connection (AD-003's `AllowAzureServices` rule should cover AKS's
egress, but confirm outbound isn't blocked by anything else); the server
itself is running (`az postgres flexible-server show`).

## Traffic Manager / DR

**Traffic Manager FQDN doesn't resolve to the expected region after a simulated failover**
DNS caching. Traffic Manager's own `dns_config.ttl` is 30s (see the
`traffic-manager` module), but intermediate resolvers (your ISP, corporate
DNS, browser DNS cache) may hold onto the old answer longer. Use `dig
+short <profile>.trafficmanager.net` from a fresh resolver, or wait out the
TTL, before concluding failover didn't work.

**Replica promotion command fails or behaves unexpectedly**
The exact `az postgres flexible-server replica promote` syntax is flagged
UNVERIFIED in `docs/dr-runbook.md` — confirm current flags against `az
postgres flexible-server replica --help` and current Microsoft Learn docs
before relying on this runbook verbatim; the CLI surface for replica
management has changed across versions.
