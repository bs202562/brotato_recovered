#!/usr/bin/env python3
"""Record one verified Tripo generation submission in the canonical ledger."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "docs" / "tripo-production-2026-09-06.json"
BRIEFS = ROOT / "docs" / "tripo-remaining-briefs.json"


def main() -> None:
    if len(sys.argv) != 5:
        raise SystemExit("usage: record-tripo-submission.py ID UUID URL BALANCE")
    identity, studio_id, url, balance_text = sys.argv[1:]
    balance = int(balance_text)
    ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
    if any(a.get("studio_id") == studio_id for a in ledger["assets"]):
        print(f"already recorded: {studio_id}")
        return
    if any(
        a.get("target_identity") == identity
        and "reject" not in str(a.get("status", "")).lower()
        for a in ledger["assets"]
    ):
        raise SystemExit(f"refusing duplicate active identity: {identity}")
    briefs = json.loads(BRIEFS.read_text(encoding="utf-8"))["briefs"]
    brief = next((b for b in briefs if b["id"] == identity), None)
    if brief is None:
        raise SystemExit(f"brief not found: {identity}")
    ledger["assets"].append(
        {
            "id": identity,
            "target_identity": identity,
            "studio_id": studio_id,
            "url": url,
            "generation_credits": 55,
            "status": "submitted_pending_generation",
            "target_triangles": brief["target_triangles"],
            "brief": brief["brief"],
        }
    )
    ledger["latest_observed_balance"] = balance
    ledger["credits_spent_this_batch"] = ledger["starting_balance"] - balance
    LEDGER.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"recorded {identity} {studio_id} balance={balance}")


if __name__ == "__main__":
    main()
