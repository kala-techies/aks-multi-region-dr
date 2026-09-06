def test_healthz(client):
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_readyz(client):
    resp = client.get("/readyz")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ready"


def test_status_operational_when_no_incidents(client):
    resp = client.get("/status")
    assert resp.status_code == 200
    body = resp.json()
    assert body["overall"] == "operational"
    assert body["open_incidents"] == 0


def test_status_reflects_severity(client, auth_headers):
    svc = client.post(
        "/services", json={"name": "checkout-api"}, headers=auth_headers
    ).json()
    client.post(
        f"/services/{svc['id']}/incidents",
        json={"title": "Payments down", "severity": "critical"},
        headers=auth_headers,
    )

    resp = client.get("/status")
    body = resp.json()
    assert body["overall"] == "major_outage"
    assert body["open_incidents"] == 1


def test_metrics_endpoint_exposes_prometheus_format(client):
    client.get("/healthz")  # generate at least one recorded request
    resp = client.get("/metrics")
    assert resp.status_code == 200
    assert b"resilientops_requests_total" in resp.content
