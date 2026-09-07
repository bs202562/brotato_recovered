#!/usr/bin/env python3
"""Merge completed sub-agent Tripo records into the canonical production ledger.

Studio UUID is the immutable key.  Handoff values fill missing fields and update
download/export facts, while the canonical identity, brief and review status are
kept when they already contain stronger information.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CANONICAL = ROOT / "docs" / "tripo-production-2026-09-06.json"
HANDOFFS = [
    ROOT / "docs" / "tripo-secondary-production-handoff.json",
    ROOT / "docs" / "tripo-tertiary-production-handoff.json",
]

STATUS_RANK = {
    "submitted_pending_generation": 1,
    "pending_generation": 1,
    "generated_pending_rigging": 2,
    "rigged_pending_animation": 3,
    "animated_pending_export": 4,
    "downloaded_pending_validation": 5,
    "downloaded_imported_engine_reviewed": 6,
}


def status_rank(value: object) -> int:
    return STATUS_RANK.get(str(value), 0)


def merge_record(dst: dict, src: dict) -> None:
    protected = {"id", "target_identity", "brief", "prompt"}
    for key, value in src.items():
        if value in (None, "", [], {}):
            continue
        if key == "status":
            if status_rank(value) >= status_rank(dst.get(key)):
                dst[key] = value
        elif key not in protected or key not in dst:
            dst[key] = value
    if "brief" not in dst and src.get("prompt"):
        dst["brief"] = src["prompt"]


def main() -> None:
    ledger = json.loads(CANONICAL.read_text(encoding="utf-8"))
    assets = ledger["assets"]
    by_uuid = {a["studio_id"]: a for a in assets if a.get("studio_id")}
    added = updated = 0

    for path in HANDOFFS:
        handoff = json.loads(path.read_text(encoding="utf-8"))
        for src in handoff.get("assets", []):
            studio_id = src.get("studio_id")
            if not studio_id:
                continue
            if studio_id in by_uuid:
                merge_record(by_uuid[studio_id], src)
                updated += 1
                continue
            record = dict(src)
            if "brief" not in record and record.get("prompt"):
                record["brief"] = record["prompt"]
            assets.append(record)
            by_uuid[studio_id] = record
            added += 1

    ids = [a.get("studio_id") for a in assets if a.get("studio_id")]
    if len(ids) != len(set(ids)):
        raise SystemExit("refusing to write duplicate Studio UUIDs")

    observed = [ledger.get("latest_observed_balance")]
    for path in HANDOFFS:
        handoff = json.loads(path.read_text(encoding="utf-8"))
        observed.append(handoff.get("latest_observed_balance"))
        observed.extend(a.get("observed_balance") for a in handoff.get("assets", []))
        observed.extend(a.get("observed_balance_after") for a in handoff.get("assets", []))
    balances = [v for v in observed if isinstance(v, int)]
    if balances:
        ledger["latest_observed_balance"] = min(balances)

    CANONICAL.write_text(
        json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        f"merged: added={added} updated={updated} total={len(assets)} "
        f"unique_studio_ids={len(set(ids))} balance={ledger.get('latest_observed_balance')}"
    )


if __name__ == "__main__":
    main()
