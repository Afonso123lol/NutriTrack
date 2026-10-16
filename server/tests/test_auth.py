import pytest

from app.main import create_app
from tests.conftest import TOKEN


def test_health_with_token(client):
    response = client.get("/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_missing_token_is_401(anonymous):
    assert anonymous.get("/v1/health").status_code == 401


def test_wrong_token_is_401(anonymous):
    response = anonymous.get("/v1/health", headers={"Authorization": "Bearer " + "x" * 43})
    assert response.status_code == 401


def test_wrong_scheme_is_401(anonymous):
    assert anonymous.get("/v1/health", headers={"Authorization": f"Basic {TOKEN}"}).status_code == 401


def test_short_token_is_refused(tmp_path):
    with pytest.raises(ValueError):
        create_app("short", tmp_path)


def test_database_is_created_with_both_tables(client, query):
    tables = {row[0] for row in query("SELECT name FROM sqlite_master WHERE type = 'table'")}
    assert {"records", "events"} <= tables


def test_security_headers_present(client):
    headers = client.get("/v1/health").headers
    assert headers["x-content-type-options"] == "nosniff"
    assert headers["x-frame-options"] == "DENY"
    assert headers["cache-control"] == "no-store"


def test_docs_are_disabled(client):
    assert client.get("/docs").status_code == 404
    assert client.get("/openapi.json").status_code == 404
