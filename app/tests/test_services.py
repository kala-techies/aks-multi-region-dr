def test_create_service_requires_api_key(client):
    resp = client.post("/services", json={"name": "checkout-api"})
    assert resp.status_code == 401


def test_create_and_get_service(client, auth_headers):
    resp = client.post(
        "/services",
        json={"name": "checkout-api", "description": "Handles checkout", "owner_team": "payments"},
        headers=auth_headers,
    )
    assert resp.status_code == 201
    created = resp.json()
    assert created["name"] == "checkout-api"
    assert created["owner_team"] == "payments"

    resp = client.get(f"/services/{created['id']}")
    assert resp.status_code == 200
    assert resp.json()["name"] == "checkout-api"


def test_duplicate_service_name_rejected(client, auth_headers):
    client.post("/services", json={"name": "checkout-api"}, headers=auth_headers)
    resp = client.post("/services", json={"name": "checkout-api"}, headers=auth_headers)
    assert resp.status_code == 409


def test_list_services(client, auth_headers):
    client.post("/services", json={"name": "checkout-api"}, headers=auth_headers)
    client.post("/services", json={"name": "auth-api"}, headers=auth_headers)

    resp = client.get("/services")
    assert resp.status_code == 200
    names = [s["name"] for s in resp.json()]
    assert names == ["checkout-api", "auth-api"]


def test_get_missing_service_returns_404(client):
    resp = client.get("/services/9999")
    assert resp.status_code == 404
