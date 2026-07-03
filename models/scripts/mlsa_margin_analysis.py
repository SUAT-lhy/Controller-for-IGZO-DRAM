#!/usr/bin/env python3
"""ML-SA/ADC current margin check for the 16-state IGZO LUT."""

from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PHASEB = ROOT / "results" / "phaseB"
OUTDIR = ROOT / "results" / "margin"


def analyze_lut(lut_name: str, sigma_offset_a: float = 80e-9, sigma_mismatch_frac: float = 0.04) -> dict:
    data = json.loads((PHASEB / lut_name).read_text(encoding="utf-8"))
    currents = [float(x) for x in data["IRBL_A"]]
    rows = []
    worst = None
    for state in range(len(currents) - 1):
        lo = currents[state]
        hi = currents[state + 1]
        delta = hi - lo
        sigma_mismatch = sigma_mismatch_frac * max(abs(lo), abs(hi))
        sigma_total = (sigma_offset_a**2 + sigma_mismatch**2) ** 0.5
        margin_sigma = delta / sigma_total if sigma_total > 0 else float("inf")
        row = {
            "state_lo": state,
            "state_hi": state + 1,
            "i_lo_A": lo,
            "i_hi_A": hi,
            "delta_i_A": delta,
            "sigma_total_A": sigma_total,
            "margin_sigma": margin_sigma,
            "pass_4sigma": margin_sigma >= 4.0,
        }
        rows.append(row)
        if worst is None or margin_sigma < worst["margin_sigma"]:
            worst = row
    return {
        "corner": data["corner"],
        "lut": lut_name,
        "sigma_offset_A": sigma_offset_a,
        "sigma_mismatch_frac": sigma_mismatch_frac,
        "worst_pair": worst,
        "all_pass_4sigma": all(row["pass_4sigma"] for row in rows),
        "rows": rows,
    }


def main() -> None:
    OUTDIR.mkdir(parents=True, exist_ok=True)
    summaries = []
    for name in ("irbl_lut_OHAD.json", "irbl_lut_nominal.json"):
        if not (PHASEB / name).exists():
            continue
        result = analyze_lut(name)
        summaries.append(result)
        csv_path = OUTDIR / f"{Path(name).stem}_margin.csv"
        with csv_path.open("w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=list(result["rows"][0].keys()))
            writer.writeheader()
            writer.writerows(result["rows"])
        print(
            f"{result['corner']}: all_pass_4sigma={result['all_pass_4sigma']}, "
            f"worst={result['worst_pair']['state_lo']}->{result['worst_pair']['state_hi']}, "
            f"margin={result['worst_pair']['margin_sigma']:.2f} sigma"
        )
    (OUTDIR / "mlsa_margin_summary.json").write_text(
        json.dumps(summaries, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
