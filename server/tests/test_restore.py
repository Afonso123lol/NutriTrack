from fastapi.testclient import TestClient

from app.main import create_app
from tests.conftest import TOKEN
from tests.test_batch import batch, record

TEST_TOKEN = "s" * 43
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 100
IDS = [f"6F9619FF-8B86-D011-B42D-00C04FC964{n:02X}" for n in range(5)]


def test_listing_needs_the_token(anonymous):
    assert anonymous.get("/v1/records").status_code == 401
    assert anonymous.get(f"/v1/photos/{IDS[0]}").status_code == 401


def test_listing_returns_live_records_with_their_payload(client):
    client.post("/v1/batch", json=batch([
        record(record_id=IDS[0], payload={"calories": 520, "dishName": "Eggs"}),
        record(entity="WeightEntry", record_id=IDS[1], payload={"weightKg": 75.4}),
        record(record_id=IDS[2], deleted=True),
    ]))
    body = client.get("/v1/records").json()
    assert body["next"] is None
    assert body["records"] == [
        {"entity": "FoodEntry", "id": IDS[0].lower(), "updatedAt": "2026-10-01T12:00:00.000000Z",
         "payload": {"calories": 520, "dishName": "Eggs"}},
        {"entity": "WeightEntry", "id": IDS[1].lower(), "updatedAt": "2026-10-01T12:00:00.000000Z",
         "payload": {"weightKg": 75.4}},
    ]


def test_listing_is_paged_with_a_cursor(client):
    client.post("/v1/batch", json=batch([record(record_id=i, payload={"calories": n}) for n, i in enumerate(IDS)]))
    first = client.get("/v1/records", params={"limit": 2}).json()
    assert [r["payload"]["calories"] for r in first["records"]] == [0, 1]
    second = client.get("/v1/records", params={"limit": 2, "after": first["next"]}).json()
    assert [r["payload"]["calories"] for r in second["records"]] == [2, 3]
    third = client.get("/v1/records", params={"limit": 2, "after": second["next"]}).json()
    assert [r["payload"]["calories"] for r in third["records"]] == [4]
    assert third["next"] is None


def test_listing_rejects_bad_paging(client):
    assert client.get("/v1/records", params={"limit": 0}).status_code == 422
    assert client.get("/v1/records", params={"limit": 5000}).status_code == 422
    assert client.get("/v1/records", params={"after": -1}).status_code == 422


def test_photo_can_be_read_back(client):
    client.put(f"/v1/photos/{IDS[0]}", content=JPEG, headers={"Content-Type": "image/jpeg"})
    response = client.get(f"/v1/photos/{IDS[0]}")
    assert response.status_code == 200
    assert response.headers["content-type"] == "image/jpeg"
    assert response.content == JPEG


def test_missing_or_malformed_photo_is_not_found(client):
    assert client.get(f"/v1/photos/{IDS[1]}").status_code == 404
    assert client.get("/v1/photos/not-a-uuid").status_code == 422


def test_test_token_reads_and_writes_a_separate_store(data_dir):
    app = create_app(TOKEN, data_dir, test_token=TEST_TOKEN)
    real = TestClient(app, headers={"Authorization": f"Bearer {TOKEN}"})
    test = TestClient(app, headers={"Authorization": f"Bearer {TEST_TOKEN}"})
    test.post("/v1/batch", json=batch([record(record_id=IDS[0], payload={"dishName": "Fake curry"})]))
    test.put(f"/v1/photos/{IDS[0]}", content=JPEG, headers={"Content-Type": "image/jpeg"})
    real.post("/v1/batch", json=batch([record(record_id=IDS[1], payload={"dishName": "Real lunch"})]))

    assert [r["payload"]["dishName"] for r in real.get("/v1/records").json()["records"]] == ["Real lunch"]
    assert [r["payload"]["dishName"] for r in test.get("/v1/records").json()["records"]] == ["Fake curry"]
    assert real.get(f"/v1/photos/{IDS[0]}").status_code == 404
    assert test.get(f"/v1/photos/{IDS[0]}").status_code == 200
    assert (data_dir / "test" / "nutritrack.db").exists()


def test_test_token_must_be_long_and_different():
    import pytest
    with pytest.raises(ValueError):
        create_app(TOKEN, __import__("pathlib").Path("/tmp/unused"), test_token="short")
    with pytest.raises(ValueError):
        create_app(TOKEN, __import__("pathlib").Path("/tmp/unused"), test_token=TOKEN)


def test_without_a_test_token_only_the_real_one_works(data_dir):
    app = create_app(TOKEN, data_dir)
    assert TestClient(app, headers={"Authorization": f"Bearer {TEST_TOKEN}"}).get("/v1/records").status_code == 401


def test_check_in_and_profile_keep_the_version_six_fields(client):
    check_in = {"energyLevel": 4, "soreness": 2, "stress": 5, "dayEnergy": 3, "suggestionChoice": "kept",
                "wakeTime": "2026-10-14T06:40:00.000Z"}
    profile = {"sleepNeedHours": 8.5, "yellowMode": "suggest"}
    response = client.post("/v1/batch", json=batch([
        record(entity="DailyCheckIn", record_id=IDS[0], payload=check_in),
        record(entity="UserProfile", record_id=IDS[1], payload=profile),
    ]))
    assert response.json()["accepted"] == 2
    assert response.json()["rejected"] == []
    payloads = {item["entity"]: item["payload"] for item in client.get("/v1/records").json()["records"]}
    assert payloads == {"DailyCheckIn": check_in, "UserProfile": profile}
