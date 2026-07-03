#!/usr/bin/env python3
"""INT4 readout model using two reliable 2-bit IGZO cells.

Storage mapping:
    INT4 value = low_2b + 4 * high_2b

Each 2-bit cell uses four open-loop write levels selected away from the
subthreshold and high-saturation edges:
    symbol 0/1/2/3 -> VSN = 0.35/0.60/0.85/1.10 V

Readout architecture:
    1. Read low slice with a 2-bit current SA/ADC.
    2. Read high slice with the same 2-bit current SA/ADC.
    3. Recombine digitally as low + 4*high.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LUT_PATH = ROOT / "results" / "phaseB" / "irbl_lut_OHAD.json"

TWO_BIT_VSN = [0.35, 0.60, 0.85, 1.10]


def load_lut() -> tuple[list[float], list[float]]:
    data = json.loads(LUT_PATH.read_text(encoding="utf-8"))
    return list(map(float, data["VSN_V"])), list(map(float, data["IRBL_A"]))


def interp(x: float, xp: list[float], fp: list[float]) -> float:
    if x <= xp[0]:
        return fp[0]
    if x >= xp[-1]:
        return fp[-1]
    for idx in range(len(xp) - 1):
        if xp[idx] <= x <= xp[idx + 1]:
            frac = (x - xp[idx]) / (xp[idx + 1] - xp[idx])
            return fp[idx] + frac * (fp[idx + 1] - fp[idx])
    return fp[-1]


def decode_symbol(current: float, thresholds: list[float]) -> int:
    symbol = 0
    for threshold in thresholds:
        if current >= threshold:
            symbol += 1
    return symbol


def popcount(value: int) -> int:
    return bin(value).count("1")


def build_two_bit_adc(xp: list[float], fp: list[float]) -> dict:
    levels = [interp(vsn, xp, fp) for vsn in TWO_BIT_VSN]
    thresholds = [(levels[idx] + levels[idx + 1]) / 2.0 for idx in range(3)]
    return {
        "vsn_levels_V": TWO_BIT_VSN,
        "current_levels_A": levels,
        "thresholds_A": thresholds,
    }


def sample_current(
    symbol: int,
    xp: list[float],
    fp: list[float],
    rng: random.Random,
    sigma_vth_v: float,
    sigma_sa_rel: float,
    sigma_offset_a: float,
) -> float:
    # A positive Vth shift reduces effective VGS; model it as VSN shift.
    effective_vsn = max(0.0, TWO_BIT_VSN[symbol] - rng.gauss(0.0, sigma_vth_v))
    ideal = interp(effective_vsn, xp, fp)
    rel_noise = rng.gauss(0.0, sigma_sa_rel) * ideal
    abs_noise = rng.gauss(0.0, sigma_offset_a)
    return max(0.0, ideal + rel_noise + abs_noise)


def run_mc(
    samples_per_value: int,
    sigma_vth_v: float,
    sigma_sa_rel: float,
    sigma_offset_a: float,
    seed: int,
) -> dict:
    rng = random.Random(seed)
    xp, fp = load_lut()
    adc = build_two_bit_adc(xp, fp)
    confusion = [[0 for _ in range(16)] for _ in range(16)]
    symbol_errors = 0
    bit_errors = 0
    total_symbols = 0
    total_bits = 0
    value_errors = 0
    total_values = 0

    for value in range(16):
        low = value & 0x3
        high = (value >> 2) & 0x3
        for _ in range(samples_per_value):
            i_low = sample_current(low, xp, fp, rng, sigma_vth_v, sigma_sa_rel, sigma_offset_a)
            i_high = sample_current(high, xp, fp, rng, sigma_vth_v, sigma_sa_rel, sigma_offset_a)
            low_hat = decode_symbol(i_low, adc["thresholds_A"])
            high_hat = decode_symbol(i_high, adc["thresholds_A"])
            decoded = low_hat + 4 * high_hat
            confusion[value][decoded] += 1
            value_errors += int(decoded != value)
            total_values += 1
            symbol_errors += int(low_hat != low) + int(high_hat != high)
            total_symbols += 2
            bit_errors += popcount(low ^ low_hat) + popcount(high ^ high_hat)
            total_bits += 4

    margin_rows = []
    for idx in range(3):
        delta_i = adc["current_levels_A"][idx + 1] - adc["current_levels_A"][idx]
        # Two adjacent states both carry Vth variation; use RSS in voltage domain
        # and local dI/dV by finite difference as a first-order equivalent.
        delta_v = TWO_BIT_VSN[idx + 1] - TWO_BIT_VSN[idx]
        local_slope = delta_i / delta_v
        sigma_device_i = local_slope * math.sqrt(2.0) * sigma_vth_v
        sigma_sa_i = sigma_sa_rel * max(adc["current_levels_A"][idx], adc["current_levels_A"][idx + 1])
        sigma_total = math.sqrt(sigma_device_i**2 + sigma_sa_i**2 + sigma_offset_a**2)
        margin_rows.append({
            "pair": f"{idx}->{idx+1}",
            "delta_v_V": delta_v,
            "delta_i_A": delta_i,
            "sigma_device_i_A": sigma_device_i,
            "sigma_sa_i_A": sigma_sa_i,
            "sigma_offset_A": sigma_offset_a,
            "sigma_total_A": sigma_total,
            "margin_sigma": delta_i / sigma_total if sigma_total else float("inf"),
        })

    return {
        "mapping": "INT4 = low_2b + 4*high_2b",
        "two_bit_vsn_levels_V": TWO_BIT_VSN,
        "adc": adc,
        "assumptions": {
            "samples_per_value": samples_per_value,
            "sigma_vth_V": sigma_vth_v,
            "sigma_sa_rel": sigma_sa_rel,
            "sigma_offset_A": sigma_offset_a,
            "seed": seed,
        },
        "metrics": {
            "value_error_rate": value_errors / total_values,
            "symbol_error_rate": symbol_errors / total_symbols,
            "bit_error_rate": bit_errors / total_bits,
            "total_values": total_values,
        },
        "margin_rows": margin_rows,
        "confusion": confusion,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--outdir", default=str(ROOT / "results" / "int4"))
    parser.add_argument("--samples-per-value", type=int, default=20000)
    parser.add_argument("--sigma-vth-v", type=float, default=0.025)
    parser.add_argument("--sigma-sa-rel", type=float, default=0.015)
    parser.add_argument("--sigma-offset-a", type=float, default=0.0)
    parser.add_argument("--seed", type=int, default=11)
    args = parser.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    result = run_mc(
        samples_per_value=args.samples_per_value,
        sigma_vth_v=args.sigma_vth_v,
        sigma_sa_rel=args.sigma_sa_rel,
        sigma_offset_a=args.sigma_offset_a,
        seed=args.seed,
    )

    (outdir / "int4_readout_summary.json").write_text(
        json.dumps(result, indent=2), encoding="utf-8"
    )
    with (outdir / "int4_margin.csv").open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(result["margin_rows"][0].keys()))
        writer.writeheader()
        writer.writerows(result["margin_rows"])
    with (outdir / "int4_confusion.csv").open("w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        writer.writerow(["actual"] + [f"decoded_{idx}" for idx in range(16)])
        for idx, row in enumerate(result["confusion"]):
            writer.writerow([idx] + row)

    metrics = result["metrics"]
    worst_margin = min(row["margin_sigma"] for row in result["margin_rows"])
    print(f"INT4 two-slice readout: value_error_rate={metrics['value_error_rate']:.3e}")
    print(f"symbol_error_rate={metrics['symbol_error_rate']:.3e}")
    print(f"bit_error_rate={metrics['bit_error_rate']:.3e}")
    print(f"worst_2bit_margin={worst_margin:.2f} sigma")
    print(f"outputs={outdir}")


if __name__ == "__main__":
    main()
