PHOTO_ID = "6F9619FF-8B86-D011-B42D-00C04FC964FF"
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 100


def put(client, photo_id, data):
    return client.put(f"/v1/photos/{photo_id}", content=data, headers={"Content-Type": "image/jpeg"})


def test_photo_is_saved_under_canonical_name(client, data_dir):
    assert put(client, PHOTO_ID, JPEG).status_code == 204
    photos = data_dir / "photos"
    assert (photos / f"{PHOTO_ID.lower()}.jpg").read_bytes() == JPEG
    assert [p.name for p in photos.iterdir()] == [f"{PHOTO_ID.lower()}.jpg"]


def test_replacing_a_photo_overwrites_it(client, data_dir):
    put(client, PHOTO_ID, JPEG)
    second = b"\xff\xd8\xff\xe1" + b"\x01" * 50
    assert put(client, PHOTO_ID, second).status_code == 204
    assert (data_dir / "photos" / f"{PHOTO_ID.lower()}.jpg").read_bytes() == second


def test_non_uuid_id_is_422(client, data_dir):
    assert put(client, "not-a-uuid", JPEG).status_code == 422
    assert list((data_dir / "photos").iterdir()) == []


def test_non_jpeg_bytes_are_422(client, data_dir):
    assert put(client, PHOTO_ID, b"\x89PNG\r\n\x1a\n" + b"\x00" * 10).status_code == 422
    assert list((data_dir / "photos").iterdir()) == []


def test_photo_over_three_megabytes_is_413(client, data_dir):
    assert put(client, PHOTO_ID, JPEG[:3] + b"\x00" * (3 * 1024 * 1024)).status_code == 413
    assert list((data_dir / "photos").iterdir()) == []


def test_photo_requires_token(anonymous, data_dir):
    assert put(anonymous, PHOTO_ID, JPEG).status_code == 401
    assert list((data_dir / "photos").iterdir()) == []


def food_record(deleted, updated_at):
    return {"deviceID": "device-1", "records": [
        {"entity": "FoodEntry", "id": PHOTO_ID, "deleted": deleted, "updatedAt": updated_at, "payload": {}}
    ], "events": []}


def test_deleting_a_meal_removes_its_photo(client, data_dir):
    put(client, PHOTO_ID, JPEG)
    client.post("/v1/batch", json=food_record(False, "2026-10-01T12:00:00Z"))
    assert (data_dir / "photos" / f"{PHOTO_ID.lower()}.jpg").exists()
    client.post("/v1/batch", json=food_record(True, "2026-10-01T13:00:00Z"))
    assert list((data_dir / "photos").iterdir()) == []


def test_stale_tombstone_keeps_the_photo(client, data_dir):
    put(client, PHOTO_ID, JPEG)
    client.post("/v1/batch", json=food_record(False, "2026-10-01T12:00:00Z"))
    client.post("/v1/batch", json=food_record(True, "2026-10-01T11:00:00Z"))
    assert (data_dir / "photos" / f"{PHOTO_ID.lower()}.jpg").exists()


def test_photo_is_refused_when_the_disk_is_almost_full(client, data_dir, monkeypatch):
    import shutil
    from collections import namedtuple
    Usage = namedtuple("Usage", "total used free")
    monkeypatch.setattr(shutil, "disk_usage", lambda path: Usage(10**12, 10**12, 10**6))
    assert put(client, PHOTO_ID, JPEG).status_code == 507
    assert list((data_dir / "photos").iterdir()) == []
