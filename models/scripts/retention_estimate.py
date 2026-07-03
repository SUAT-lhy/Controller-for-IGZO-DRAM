#!/usr/bin/env python3
"""Retention sweep for the IGZO 2T0C v1.1 planning model."""

from __future__ import annotations

import csv
from pathlib import Path


def retention_margin(ioff_a_per_um: float, w_um: float, csn_f: float, d_v_limit: float = 0.1) -> float:
    """Return t_ret = Csn * dV / (Ioff * W).

    Ioff is normalized by channel width in A/um and W is in um, so their
    product is the absolute leakage current in ampere.
    """
    i_leak_a = ioff_a_per_um * w_um
    if i_leak_a <= 0:
        raise ValueError("Leakage current must be positive")
    return d_v_limit * csn_f / i_leak_a


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    out_dir = root / "results"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_csv = out_dir / "retention_matrix.csv"

    corners = [
        ("pilot", 1e-14),
        ("nominal", 1e-16),
        ("transition", 1e-18),
        ("OHAD", 1e-19),
    ]
    csn_values = [2e-15, 5e-15, 10e-15]
    rows = []
    for name, ioff in corners:
        for csn in csn_values:
            rows.append(
                {
                    "corner": name,
                    "ioff_A_per_um": f"{ioff:.3e}",
                    "Csn_fF": f"{csn / 1e-15:.1f}",
                    "W_um": "0.5",
                    "dV_limit_V": "0.1",
                    "t_ret_s": f"{retention_margin(ioff, 0.5, csn):.6e}",
                }
            )

    with out_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {out_csv}")
    for row in rows:
        if row["Csn_fF"] == "5.0":
            print(row["corner"], row["t_ret_s"], "s")


if __name__ == "__main__":
    main()
