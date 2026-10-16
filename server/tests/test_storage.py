import sqlite3

from app.main import create_app
from tests.conftest import TOKEN

OLD_SCHEMA = """
CREATE TABLE records (
    entity TEXT NOT NULL,
    id TEXT NOT NULL,
    deleted INTEGER NOT NULL,
    updated_at TEXT NOT NULL,
    payload TEXT NOT NULL,
    received_at TEXT NOT NULL,
    PRIMARY KEY (entity, id)
);
INSERT INTO records VALUES (
    'WeightEntry', '00000000-0000-4000-8000-000000000001', 0,
    '2026-10-01T12:00:00.000000Z', '{}', '2026-10-01T12:00:01.000000Z'
);
"""


def test_existing_database_gains_device_id_column(data_dir, query):
    data_dir.mkdir(parents=True)
    conn = sqlite3.connect(data_dir / "nutritrack.db")
    conn.executescript(OLD_SCHEMA)
    conn.close()
    create_app(TOKEN, data_dir)
    assert query("SELECT id, device_id FROM records") == [("00000000-0000-4000-8000-000000000001", "")]
