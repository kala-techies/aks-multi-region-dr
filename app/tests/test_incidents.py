def _make_service(client, auth_headers, name="checkout-api"):
    return client.post("/services", json={"name": name}, headers=auth_headers).json()


def test_create_incident_requires_api_key(client, auth_headers):
    svc = _make_service(client, auth_headers)
    resp = client.post(f"/services/{svc['id']}/incidents", json={"title": "Down"})
    assert resp.status_code == 401


def test_create_incident_seeds_opening_timeline_entry(client, auth_headers):
    svc = _make_service(client, auth_headers)
    resp = client.post(
        f"/services/{svc['id']}/incidents",
        json={"title": "Elevated error rate", "severity": "high"},
        headers=auth_headers,
    )
    assert resp.status_code == 201
    incident = resp.json()
    assert incident["status"] == "investigating"
    assert incident["severity"] == "high"
    assert len(incident["updates"]) == 1
    assert "opened" in incident["updates"][0]["message"].lower()


def test_create_incident_for_missing_service_404s(client, auth_headers):
    resp = client.post(
        "/services/9999/incidents", json={"title": "x"}, headers=auth_headers
    )
    assert resp.status_code == 404


def test_patch_incident_status_adds_timeline_entry_and_sets_resolved_at(client, auth_headers):
    svc = _make_service(client, auth_headers)
    incident = client.post(
        f"/services/{svc['id']}/incidents", json={"title": "Down"}, headers=auth_headers
    ).json()

    resp = client.patch(
        f"/incidents/{incident['id']}", json={"status": "resolved"}, headers=auth_headers
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "resolved"
    assert body["resolved_at"] is not None
    assert len(body["updates"]) == 2  # opened + resolved


def test_add_manual_incident_update(client, auth_headers):
    svc = _make_service(client, auth_headers)
    incident = client.post(
        f"/services/{svc['id']}/incidents", json={"title": "Down"}, headers=auth_headers
    ).json()

    resp = client.post(
        f"/incidents/{incident['id']}/updates",
        json={"message": "Root cause identified: bad deploy"},
        headers=auth_headers,
    )
    assert resp.status_code == 201

    resp = client.get(f"/incidents/{incident['id']}/updates")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_list_incidents_filters_by_status_and_severity(client, auth_headers):
    svc = _make_service(client, auth_headers)
    open_incident = client.post(
        f"/services/{svc['id']}/incidents",
        json={"title": "Open one", "severity": "critical"},
        headers=auth_headers,
    ).json()
    resolved_incident = client.post(
        f"/services/{svc['id']}/incidents", json={"title": "Resolved one"}, headers=auth_headers
    ).json()
    client.patch(
        f"/incidents/{resolved_incident['id']}", json={"status": "resolved"}, headers=auth_headers
    )

    resp = client.get("/incidents", params={"status": "resolved"})
    ids = [i["id"] for i in resp.json()]
    assert ids == [resolved_incident["id"]]

    resp = client.get("/incidents", params={"severity": "critical"})
    ids = [i["id"] for i in resp.json()]
    assert ids == [open_incident["id"]]


def test_get_missing_incident_returns_404(client):
    resp = client.get("/incidents/9999")
    assert resp.status_code == 404
