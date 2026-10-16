import hmac
import json
import os
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import Depends, FastAPI, HTTPException, Request, Response
from starlette.concurrency import run_in_threadpool

from app.storage import Storage

ENTITIES = frozenset({
    "FoodEntry", "SupplementLog", "SupplementTemplate", "DailyCheckIn",
    "WeightEntry", "DailyEvaluation", "UserProfile",
    "TargetSnapshot", "TrainingProfile", "TrainingWeek", "PlannedSession",
    "TrainingSession", "StrengthSet",
})
APP_STATES = frozenset({"active", "inactive", "background"})
MAX_BATCH_BYTES = 2 * 1024 * 1024
MAX_PHOTO_BYTES = 3 * 1024 * 1024
MAX_PAGE_SIZE = 500
MAX_SEQ = 2**63 - 1
MAX_CLOCK_SKEW = timedelta(days=1)
MIN_TOKEN_LENGTH = 32
JPEG_MAGIC = b"\xff\xd8\xff"
SECURITY_HEADERS = {
    "Cache-Control": "no-store",
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
    "Referrer-Policy": "no-referrer",
    "Strict-Transport-Security": "max-age=31536000",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
}


def clean_text(raw) -> str | None:
    if not isinstance(raw, str):
        return None
    try:
        raw.encode("utf-8")
    except UnicodeEncodeError:
        return None
    return raw


def dump_object(value: dict) -> str | None:
    try:
        return json.dumps(value, allow_nan=False)
    except ValueError:
        return None


def canonical_uuid(raw) -> str | None:
    if not isinstance(raw, str):
        return None
    try:
        return str(uuid.UUID(raw))
    except ValueError:
        return None


def utc_timestamp(raw) -> str | None:
    if not isinstance(raw, str):
        return None
    try:
        parsed = datetime.fromisoformat(raw)
        if parsed.tzinfo is None:
            return None
        normalised = parsed.astimezone(timezone.utc)
    except (ValueError, OverflowError):
        return None
    if normalised > datetime.now(timezone.utc) + MAX_CLOCK_SKEW:
        return None
    return normalised.strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def reject_constant(name: str):
    raise ValueError(f"Unsupported JSON constant {name}")


def parse_envelope(body: bytes) -> dict:
    try:
        data = json.loads(body, parse_constant=reject_constant)
    except (ValueError, RecursionError):
        raise HTTPException(status_code=422, detail="Body is not valid JSON")
    if not isinstance(data, dict):
        raise HTTPException(status_code=422, detail="Batch must be a JSON object")
    device_id = clean_text(data.get("deviceID"))
    if device_id is None or not 0 < len(device_id) <= 64:
        raise HTTPException(status_code=422, detail="deviceID must be a non-empty string")
    if not isinstance(data.get("records"), list) or not isinstance(data.get("events"), list):
        raise HTTPException(status_code=422, detail="records and events must be lists")
    return data


def parse_record(raw) -> tuple[dict | None, dict | None]:
    entity = clean_text(raw.get("entity")) if isinstance(raw, dict) else None
    raw_id = clean_text(raw.get("id")) if isinstance(raw, dict) else None

    def reject(reason: str):
        return None, {"entity": entity, "id": raw_id, "reason": reason}

    if not isinstance(raw, dict):
        return reject("not an object")
    if entity is None or entity not in ENTITIES:
        return reject("unknown entity")
    record_id = canonical_uuid(raw_id)
    if record_id is None:
        return reject("invalid id")
    updated_at = utc_timestamp(raw.get("updatedAt"))
    if updated_at is None:
        return reject("invalid updatedAt")
    deleted = raw.get("deleted", False)
    if not isinstance(deleted, bool):
        return reject("invalid deleted")
    payload = raw.get("payload", {} if deleted else None)
    payload_json = dump_object(payload) if isinstance(payload, dict) else None
    if payload_json is None:
        return reject("invalid payload")
    return {"entity": entity, "id": record_id, "deleted": deleted, "updated_at": updated_at, "payload": payload_json}, None


def parse_event(raw) -> tuple[dict | None, dict | None]:
    seq = raw.get("seq") if isinstance(raw, dict) else None
    valid_seq = isinstance(seq, int) and not isinstance(seq, bool) and 0 <= seq <= MAX_SEQ

    def reject(reason: str):
        return None, {"seq": seq if valid_seq else None, "reason": reason}

    if not isinstance(raw, dict):
        return reject("not an object")
    if not valid_seq:
        return reject("invalid seq")
    at = utc_timestamp(raw.get("at"))
    if at is None:
        return reject("invalid at")
    kind = clean_text(raw.get("kind"))
    if kind is None or not 0 < len(kind) <= 64:
        return reject("invalid kind")
    app_state = raw.get("appState")
    if not isinstance(app_state, str) or app_state not in APP_STATES:
        return reject("invalid appState")
    details = raw.get("details", {})
    details_json = dump_object(details) if isinstance(details, dict) else None
    if details_json is None:
        return reject("invalid details")
    return {"seq": seq, "at": at, "kind": kind, "app_state": app_state, "details": details_json}, None


def partition(parse, items: list) -> tuple[list, list]:
    valid, rejected = [], []
    for item in items:
        parsed, rejection = parse(item)
        if parsed is None:
            rejected.append(rejection)
        else:
            valid.append(parsed)
    return valid, rejected


async def read_limited(request: Request, limit: int) -> bytes:
    declared = request.headers.get("content-length", "")
    if declared.isdigit() and int(declared) > limit:
        raise HTTPException(status_code=413, detail="Payload too large")
    body = bytearray()
    async for chunk in request.stream():
        body.extend(chunk)
        if len(body) > limit:
            raise HTTPException(status_code=413, detail="Payload too large")
    return bytes(body)


def create_app(token: str, data_dir: Path, test_token: str = "") -> FastAPI:
    if len(token) < MIN_TOKEN_LENGTH:
        raise ValueError(f"Token must have at least {MIN_TOKEN_LENGTH} characters")
    if test_token and (len(test_token) < MIN_TOKEN_LENGTH or test_token == token):
        raise ValueError(f"Test token must have at least {MIN_TOKEN_LENGTH} characters and differ from the token")
    stores = [(token.encode(), Storage(data_dir))]
    if test_token:
        stores.append((test_token.encode(), Storage(data_dir / "test")))

    def require_token(request: Request) -> None:
        scheme, _, provided = request.headers.get("authorization", "").partition(" ")
        matched = None
        if scheme.lower() == "bearer":
            for expected, store in stores:
                if hmac.compare_digest(provided.encode(), expected):
                    matched = store
        if matched is None:
            raise HTTPException(status_code=401, detail="Unauthorized", headers={"WWW-Authenticate": "Bearer"})
        request.state.storage = matched

    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None, dependencies=[Depends(require_token)])

    @app.middleware("http")
    async def security_headers(request: Request, call_next):
        response = await call_next(request)
        response.headers.update(SECURITY_HEADERS)
        return response

    @app.get("/v1/health")
    def health():
        return {"status": "ok"}

    @app.post("/v1/batch")
    async def batch(request: Request):
        envelope = parse_envelope(await read_limited(request, MAX_BATCH_BYTES))
        records, rejected = partition(parse_record, envelope["records"])
        events, rejected_events = partition(parse_event, envelope["events"])
        received_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
        await run_in_threadpool(request.state.storage.save_batch, envelope["deviceID"], records, events, received_at)
        return {
            "accepted": len(records),
            "rejected": rejected,
            "eventsAccepted": len(events),
            "rejectedEvents": rejected_events,
        }

    @app.put("/v1/photos/{photo_id}", status_code=204)
    async def photo(photo_id: str, request: Request):
        canonical = canonical_uuid(photo_id)
        if canonical is None:
            raise HTTPException(status_code=422, detail="Photo id must be a UUID")
        if not request.state.storage.has_room():
            raise HTTPException(status_code=507, detail="Insufficient storage")
        data = await read_limited(request, MAX_PHOTO_BYTES)
        if not data.startswith(JPEG_MAGIC):
            raise HTTPException(status_code=422, detail="Body is not a JPEG")
        await run_in_threadpool(request.state.storage.save_photo, canonical, data)
        return Response(status_code=204)

    @app.get("/v1/records")
    async def records(request: Request, after: int = 0, limit: int = 200):
        if after < 0 or not 1 <= limit <= MAX_PAGE_SIZE:
            raise HTTPException(status_code=422, detail="Invalid paging")
        rows, next_cursor = await run_in_threadpool(request.state.storage.list_records, after, limit)
        return {
            "records": [
                {"entity": entity, "id": record_id, "updatedAt": updated_at, "payload": json.loads(payload)}
                for _, entity, record_id, updated_at, payload in rows
            ],
            "next": next_cursor,
        }

    @app.get("/v1/photos/{photo_id}")
    async def read_photo(photo_id: str, request: Request):
        canonical = canonical_uuid(photo_id)
        if canonical is None:
            raise HTTPException(status_code=422, detail="Photo id must be a UUID")
        data = await run_in_threadpool(request.state.storage.read_photo, canonical)
        if data is None:
            raise HTTPException(status_code=404, detail="Photo not found")
        return Response(content=data, media_type="image/jpeg")

    return app


def app_from_env() -> FastAPI:
    return create_app(os.environ.get("NUTRITRACK_TOKEN", ""), Path(os.environ.get("NUTRITRACK_DATA_DIR", "/data")),
                      test_token=os.environ.get("NUTRITRACK_TEST_TOKEN", ""))
