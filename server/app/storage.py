import os
import shutil
import sqlite3
import tempfile
from contextlib import closing
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS records (
    entity TEXT NOT NULL,
    id TEXT NOT NULL,
    deleted INTEGER NOT NULL,
    updated_at TEXT NOT NULL,
    payload TEXT NOT NULL,
    received_at TEXT NOT NULL,
    device_id TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (entity, id)
);
CREATE TABLE IF NOT EXISTS events (
    device_id TEXT NOT NULL,
    device_seq INTEGER NOT NULL,
    at TEXT NOT NULL,
    kind TEXT NOT NULL,
    app_state TEXT NOT NULL,
    payload TEXT NOT NULL,
    received_at TEXT NOT NULL,
    PRIMARY KEY (device_id, device_seq)
);
"""

UPSERT_RECORD = """
INSERT INTO records (entity, id, deleted, updated_at, payload, received_at, device_id)
VALUES (?, ?, ?, ?, ?, ?, ?)
ON CONFLICT (entity, id) DO UPDATE SET
    deleted = excluded.deleted,
    updated_at = excluded.updated_at,
    payload = excluded.payload,
    received_at = excluded.received_at,
    device_id = excluded.device_id
WHERE excluded.updated_at >= records.updated_at
"""

PHOTO_ENTITY = "FoodEntry"
MIN_FREE_BYTES = 1024**3

INSERT_EVENT = """
INSERT OR IGNORE INTO events (device_id, device_seq, at, kind, app_state, payload, received_at)
VALUES (?, ?, ?, ?, ?, ?, ?)
"""


class Storage:
    def __init__(self, data_dir: Path):
        self.db_path = data_dir / "nutritrack.db"
        self.photos_dir = data_dir / "photos"
        self.photos_dir.mkdir(parents=True, exist_ok=True)
        with closing(self._connect()) as conn:
            conn.execute("PRAGMA journal_mode=WAL")
            conn.executescript(SCHEMA)
            columns = {row[1] for row in conn.execute("PRAGMA table_info(records)")}
            if "device_id" not in columns:
                conn.execute("ALTER TABLE records ADD COLUMN device_id TEXT NOT NULL DEFAULT ''")
                conn.commit()

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self.db_path, timeout=5)

    def save_batch(self, device_id: str, records: list[dict], events: list[dict], received_at: str) -> None:
        record_rows = [
            (r["entity"], r["id"], int(r["deleted"]), r["updated_at"], r["payload"], received_at, device_id)
            for r in records
        ]
        event_rows = [
            (device_id, e["seq"], e["at"], e["kind"], e["app_state"], e["details"], received_at)
            for e in events
        ]
        tombstones = [r["id"] for r in records if r["entity"] == PHOTO_ENTITY and r["deleted"]]
        removed: list[str] = []
        with closing(self._connect()) as conn, conn:
            conn.executemany(UPSERT_RECORD, record_rows)
            conn.executemany(INSERT_EVENT, event_rows)
            if tombstones:
                placeholders = ",".join("?" * len(tombstones))
                rows = conn.execute(
                    f"SELECT id FROM records WHERE entity = ? AND deleted = 1 AND id IN ({placeholders})",
                    [PHOTO_ENTITY, *tombstones],
                )
                removed = [row[0] for row in rows]
        for photo_id in removed:
            (self.photos_dir / f"{photo_id}.jpg").unlink(missing_ok=True)

    def list_records(self, after: int, limit: int) -> tuple[list[tuple], int | None]:
        with closing(self._connect()) as conn:
            rows = conn.execute(
                "SELECT rowid, entity, id, updated_at, payload FROM records "
                "WHERE deleted = 0 AND rowid > ? ORDER BY rowid LIMIT ?",
                (after, limit + 1),
            ).fetchall()
        page = rows[:limit]
        return page, (page[-1][0] if len(rows) > limit else None)

    def read_photo(self, photo_id: str) -> bytes | None:
        try:
            return (self.photos_dir / f"{photo_id}.jpg").read_bytes()
        except FileNotFoundError:
            return None

    def has_room(self) -> bool:
        return shutil.disk_usage(self.photos_dir).free >= MIN_FREE_BYTES

    def save_photo(self, photo_id: str, data: bytes) -> None:
        fd, tmp_name = tempfile.mkstemp(dir=self.photos_dir, suffix=".tmp")
        tmp_path = Path(tmp_name)
        try:
            with os.fdopen(fd, "wb") as handle:
                handle.write(data)
            os.replace(tmp_path, self.photos_dir / f"{photo_id}.jpg")
        except BaseException:
            tmp_path.unlink(missing_ok=True)
            raise
