import json

FOOD_ID = "6F9619FF-8B86-D011-B42D-00C04FC964FF"


def record(entity="FoodEntry", record_id=FOOD_ID, updated_at="2026-10-01T12:00:00Z", payload=None, deleted=False):
    item = {"entity": entity, "id": record_id, "deleted": deleted, "updatedAt": updated_at}
    if payload is not None:
        item["payload"] = payload
    return item


def event(seq=1, kind="model.enqueued", app_state="active", details=None):
    return {"seq": seq, "at": "2026-10-01T12:00:01+01:00", "kind": kind, "appState": app_state,
            "details": details if details is not None else {"jobID": "abc"}}


def batch(records=(), events=()):
    return {"deviceID": "device-1", "sentAt": "2026-10-01T12:00:05Z", "records": list(records), "events": list(events)}


def test_batch_without_token_writes_nothing(anonymous, query):
    assert anonymous.post("/v1/batch", json=batch([record(payload={"calories": 1})], [event()])).status_code == 401
    assert query("SELECT COUNT(*) FROM records") == [(0,)]
    assert query("SELECT COUNT(*) FROM events") == [(0,)]


def test_valid_record_is_stored_with_canonical_id(client, query):
    response = client.post("/v1/batch", json=batch([record(payload={"calories": 520})]))
    assert response.status_code == 200
    assert response.json()["accepted"] == 1
    assert response.json()["rejected"] == []
    rows = query("SELECT entity, id, deleted, updated_at, payload FROM records")
    assert rows == [("FoodEntry", FOOD_ID.lower(), 0, "2026-10-01T12:00:00.000000Z", '{"calories": 520}')]


def test_invalid_records_are_rejected_and_valid_ones_kept(client, query):
    response = client.post("/v1/batch", json=batch([
        record(payload={"calories": 520}),
        record(entity="Hacker", payload={}),
        record(record_id="not-a-uuid", payload={}),
        record(entity="WeightEntry", record_id="00000000-0000-4000-8000-000000000001", payload="x"),
        record(entity="WeightEntry", record_id="00000000-0000-4000-8000-000000000002", updated_at="2026-10-01T12:00:00", payload={}),
        record(entity=["FoodEntry"], payload={}),
        "not an object",
    ]))
    assert response.status_code == 200
    body = response.json()
    assert body["accepted"] == 1
    assert [r["reason"] for r in body["rejected"]] == [
        "unknown entity", "invalid id", "invalid payload", "invalid updatedAt", "unknown entity", "not an object",
    ]
    assert body["rejected"][1] == {"entity": "FoodEntry", "id": "not-a-uuid", "reason": "invalid id"}
    assert query("SELECT COUNT(*) FROM records") == [(1,)]


def test_resending_the_same_batch_does_not_duplicate(client, query):
    body = batch([record(payload={"calories": 520})], [event()])
    client.post("/v1/batch", json=body)
    client.post("/v1/batch", json=body)
    assert query("SELECT COUNT(*) FROM records") == [(1,)]
    assert query("SELECT COUNT(*) FROM events") == [(1,)]


def test_older_update_does_not_overwrite_newer(client, query):
    client.post("/v1/batch", json=batch([record(updated_at="2026-10-01T12:00:00Z", payload={"calories": 600})]))
    client.post("/v1/batch", json=batch([record(updated_at="2026-10-01T12:30:00+01:00", payload={"calories": 500})]))
    assert json.loads(query("SELECT payload FROM records")[0][0]) == {"calories": 600}


def test_newer_update_overwrites(client, query):
    client.post("/v1/batch", json=batch([record(updated_at="2026-10-01T12:00:00Z", payload={"calories": 600})]))
    client.post("/v1/batch", json=batch([record(updated_at="2026-10-01T12:00:00.5Z", payload={"calories": 700})]))
    assert json.loads(query("SELECT payload FROM records")[0][0]) == {"calories": 700}


def test_tombstone_without_payload_marks_deleted(client, query):
    client.post("/v1/batch", json=batch([record(payload={"calories": 600})]))
    response = client.post("/v1/batch", json=batch([record(updated_at="2026-10-01T13:00:00Z", deleted=True)]))
    assert response.json()["accepted"] == 1
    assert query("SELECT deleted, payload FROM records") == [(1, "{}")]


def test_events_are_stored_in_utc(client, query):
    response = client.post("/v1/batch", json=batch(events=[event(seq=7, details={"durationS": 46})]))
    assert response.json()["eventsAccepted"] == 1
    rows = query("SELECT device_id, device_seq, at, kind, app_state, payload FROM events")
    assert rows == [("device-1", 7, "2026-10-01T11:00:01.000000Z", "model.enqueued", "active", '{"durationS": 46}')]


def test_invalid_events_are_rejected_and_valid_ones_kept(client, query):
    response = client.post("/v1/batch", json=batch(events=[
        event(seq=1),
        event(seq=-1),
        event(seq=True),
        event(seq=3, app_state="sleeping"),
        event(seq=4, app_state=["active"]),
        event(seq=5, kind=""),
        event(seq=6, details=[1]),
    ]))
    body = response.json()
    assert body["eventsAccepted"] == 1
    assert [e["reason"] for e in body["rejectedEvents"]] == [
        "invalid seq", "invalid seq", "invalid appState", "invalid appState", "invalid kind", "invalid details",
    ]
    assert body["rejectedEvents"][2] == {"seq": 3, "reason": "invalid appState"}
    assert query("SELECT COUNT(*) FROM events") == [(1,)]


def test_body_that_is_not_json_is_422(client):
    response = client.post("/v1/batch", content=b"not json", headers={"Content-Type": "application/json"})
    assert response.status_code == 422


def test_body_without_batch_shape_is_422(client):
    assert client.post("/v1/batch", json=[1, 2]).status_code == 422
    assert client.post("/v1/batch", json={"deviceID": "", "records": [], "events": []}).status_code == 422
    assert client.post("/v1/batch", json={"deviceID": "d", "records": []}).status_code == 422
    assert client.post("/v1/batch", json={"deviceID": "d", "records": {}, "events": []}).status_code == 422


def test_deeply_nested_json_is_422(client):
    body = b"[" * 100_000 + b"]" * 100_000
    assert client.post("/v1/batch", content=body, headers={"Content-Type": "application/json"}).status_code == 422


def test_nan_constant_is_422(client):
    body = b'{"deviceID": "d", "records": [], "events": [], "x": NaN}'
    assert client.post("/v1/batch", content=body, headers={"Content-Type": "application/json"}).status_code == 422


def test_body_over_two_megabytes_is_413(client):
    body = b"x" * (2 * 1024 * 1024 + 1)
    assert client.post("/v1/batch", content=body, headers={"Content-Type": "application/json"}).status_code == 413


def test_record_keeps_the_device_that_sent_it(client, query):
    client.post("/v1/batch", json=batch([record(payload={"calories": 520})]))
    assert query("SELECT device_id FROM records") == [("device-1",)]
    newer = batch([record(updated_at="2026-10-01T13:00:00Z", payload={"calories": 530})])
    newer["deviceID"] = "device-2"
    client.post("/v1/batch", json=newer)
    assert query("SELECT device_id FROM records") == [("device-2",)]


def test_huge_sequence_number_is_rejected_not_a_server_error(client, query):
    response = client.post("/v1/batch", json=batch(events=[event(seq=2**63)]))
    assert response.status_code == 200
    assert response.json()["rejectedEvents"] == [{"seq": None, "reason": "invalid seq"}]
    assert query("SELECT COUNT(*) FROM events") == [(0,)]


def test_timestamps_outside_the_plausible_range_are_rejected(client, query):
    response = client.post("/v1/batch", json=batch([
        record(updated_at="0001-01-01T00:00:00+14:00", payload={}),
        record(updated_at="2999-01-01T00:00:00Z", payload={}),
    ]))
    assert response.status_code == 200
    assert [r["reason"] for r in response.json()["rejected"]] == ["invalid updatedAt", "invalid updatedAt"]
    assert query("SELECT COUNT(*) FROM records") == [(0,)]


def test_infinite_number_in_payload_is_rejected(client, query):
    body = b'{"deviceID": "d", "records": [{"entity": "FoodEntry", "id": "' + FOOD_ID.encode() + \
        b'", "updatedAt": "2026-10-01T12:00:00Z", "payload": {"calories": 1e999}}], "events": []}'
    response = client.post("/v1/batch", content=body, headers={"Content-Type": "application/json"})
    assert response.status_code == 200
    assert response.json()["rejected"][0]["reason"] == "invalid payload"
    assert query("SELECT COUNT(*) FROM records") == [(0,)]


def test_lone_surrogates_do_not_break_the_response(client, query):
    body = b'{"deviceID": "d", "records": [{"entity": "\\ud800", "id": "\\ud800", "updatedAt": "x", "payload": {}}], ' \
        b'"events": [{"seq": 1, "at": "2026-10-01T12:00:00Z", "kind": "\\ud800", "appState": "active"}]}'
    response = client.post("/v1/batch", content=body, headers={"Content-Type": "application/json"})
    assert response.status_code == 200
    assert response.json()["rejected"] == [{"entity": None, "id": None, "reason": "unknown entity"}]
    assert response.json()["rejectedEvents"] == [{"seq": 1, "reason": "invalid kind"}]
    assert query("SELECT COUNT(*) FROM events") == [(0,)]


def test_training_and_target_entities_are_accepted(client, query):
    names = ["TargetSnapshot", "TrainingProfile", "TrainingWeek", "PlannedSession", "TrainingSession", "StrengthSet"]
    records = [record(entity=name, record_id=f"6F9619FF-8B86-D011-B42D-00C04FC96{n:03d}", payload={"x": 1})
               for n, name in enumerate(names)]
    response = client.post("/v1/batch", json=batch(records))
    assert response.status_code == 200
    assert response.json()["accepted"] == 6
    assert response.json()["rejected"] == []
    assert query("SELECT COUNT(DISTINCT entity) FROM records") == [(6,)]
