import sqlite3

import pytest
from fastapi.testclient import TestClient

from app.main import create_app

TOKEN = "t" * 43


@pytest.fixture
def data_dir(tmp_path):
    return tmp_path / "data"


@pytest.fixture
def client(data_dir):
    test_client = TestClient(create_app(TOKEN, data_dir))
    test_client.headers.update({"Authorization": f"Bearer {TOKEN}"})
    return test_client


@pytest.fixture
def anonymous(data_dir):
    return TestClient(create_app(TOKEN, data_dir))


@pytest.fixture
def query(data_dir):
    def run(sql: str) -> list[tuple]:
        conn = sqlite3.connect(data_dir / "nutritrack.db")
        try:
            return conn.execute(sql).fetchall()
        finally:
            conn.close()
    return run
