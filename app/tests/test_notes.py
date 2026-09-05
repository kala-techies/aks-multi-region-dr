def test_create_and_get_note(client):
    resp = client.post("/notes", json={"title": "First", "body": "hello"})
    assert resp.status_code == 201
    created = resp.json()
    assert created["title"] == "First"
    assert created["body"] == "hello"
    note_id = created["id"]

    resp = client.get(f"/notes/{note_id}")
    assert resp.status_code == 200
    assert resp.json()["title"] == "First"


def test_list_notes_empty_then_populated(client):
    resp = client.get("/notes")
    assert resp.status_code == 200
    assert resp.json() == []

    client.post("/notes", json={"title": "A", "body": ""})
    client.post("/notes", json={"title": "B", "body": ""})

    resp = client.get("/notes")
    assert resp.status_code == 200
    titles = [n["title"] for n in resp.json()]
    assert titles == ["A", "B"]


def test_update_note(client):
    created = client.post("/notes", json={"title": "Old", "body": "x"}).json()
    resp = client.put(
        f"/notes/{created['id']}", json={"title": "New", "body": "y"}
    )
    assert resp.status_code == 200
    assert resp.json()["title"] == "New"
    assert resp.json()["body"] == "y"


def test_delete_note(client):
    created = client.post("/notes", json={"title": "Temp", "body": ""}).json()
    resp = client.delete(f"/notes/{created['id']}")
    assert resp.status_code == 204

    resp = client.get(f"/notes/{created['id']}")
    assert resp.status_code == 404


def test_get_missing_note_returns_404(client):
    resp = client.get("/notes/9999")
    assert resp.status_code == 404


def test_create_note_rejects_empty_title(client):
    resp = client.post("/notes", json={"title": "", "body": "x"})
    assert resp.status_code == 422
