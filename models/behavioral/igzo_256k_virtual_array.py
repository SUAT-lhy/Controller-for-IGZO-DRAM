#!/usr/bin/env python3
"""256K IGZO virtual array model aligned to the Phase-B 2T0C cell model.

Mainline write model:
    full_swing: VSN = min(WBL, WWL - VTH) = WBL for WWL=2 V and WBL<=1.5 V.

Pessimistic corner:
    vth_drop: VSN = max(WBL - VTH, 0), used only as an under-write stress case.
"""

from __future__ import annotations

import json
import math
import random
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LUT_DIR = ROOT / "results" / "phaseB"


@dataclass(frozen=True)
class Corner:
    name: str
    vth_v: float
    ioff_a_per_um: float
    sigma_vth_v: float = 0.025
    sigma_ion_frac: float = 0.04
    lut_file: str | None = None


CORNERS = {
    "pilot": Corner("pilot", 0.63, 1e-14, 0.04, 0.08, None),
    "nominal": Corner("nominal", 0.63, 1e-16, 0.025, 0.04, "irbl_lut_nominal.json"),
    "OHAD": Corner("OHAD", 0.23, 1e-19, 0.025, 0.04, "irbl_lut_OHAD.json"),
}


def _load_lut(corner: Corner) -> tuple[list[float], list[float]] | None:
    if not corner.lut_file:
        return None
    path = LUT_DIR / corner.lut_file
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    return list(map(float, data["VSN_V"])), list(map(float, data["IRBL_A"]))


def _interp(x: float, xp: list[float], fp: list[float]) -> float:
    if x <= xp[0]:
        return fp[0]
    if x >= xp[-1]:
        return fp[-1]
    for idx in range(len(xp) - 1):
        if xp[idx] <= x <= xp[idx + 1]:
            span = xp[idx + 1] - xp[idx]
            frac = 0.0 if span == 0 else (x - xp[idx]) / span
            return fp[idx] + frac * (fp[idx + 1] - fp[idx])
    return fp[-1]


class IGZO256KArray:
    """1024 x 256 x 4-bit virtual array with selectable write assumptions."""

    def __init__(
        self,
        corner: str = "OHAD",
        csn_f: float = 5e-15,
        seed: int = 7,
        write_model: str = "full_swing",
        vwwl_on_v: float = 2.0,
    ) -> None:
        if write_model not in {"full_swing", "vth_drop"}:
            raise ValueError("write_model must be full_swing or vth_drop")
        self.rows = 1024
        self.cols = 256
        self.corner = CORNERS[corner]
        self.csn_f = csn_f
        self.write_model = write_model
        self.vwwl_on_v = vwwl_on_v
        self.rng = random.Random(seed)
        self.state = [[0 for _ in range(self.cols)] for _ in range(self.rows)]
        self.vsn = [[0.0 for _ in range(self.cols)] for _ in range(self.rows)]
        self.lut = _load_lut(self.corner)

    def state_to_write_vbl(self, state: int) -> float:
        return 0.1 * state

    def write_target_vsn(self, state: int) -> float:
        wbl = self.state_to_write_vbl(state)
        if self.write_model == "full_swing":
            return max(0.0, min(wbl, self.vwwl_on_v - self.corner.vth_v))
        return max(0.0, wbl - self.corner.vth_v)

    def write(self, row: int, col: int, state: int) -> None:
        if not 0 <= state <= 15:
            raise ValueError("state must be in [0, 15]")
        self.state[row][col] = int(state)
        self.vsn[row][col] = self.write_target_vsn(int(state))

    def drifted_vsn(self, row: int, col: int, t_hold_s: float = 0.0) -> float:
        drift_v = self.corner.ioff_a_per_um * 0.5 * t_hold_s / self.csn_f
        return max(0.0, self.vsn[row][col] - drift_v)

    def irbl_from_vsn(self, vsn_v: float, vary: bool = True) -> float:
        if self.lut is not None:
            base = _interp(vsn_v, self.lut[0], self.lut[1])
        else:
            # Fallback only for corners without a Phase-B LUT.
            vgt = max(vsn_v - self.corner.vth_v, 0.0)
            base = self.corner.ioff_a_per_um * 0.5 * math.exp(min(vgt / 0.075, 8.0))
        if not vary:
            return max(base, 0.0)
        ion_scale = max(0.0, self.rng.gauss(1.0, self.corner.sigma_ion_frac))
        dvth = self.rng.gauss(0.0, self.corner.sigma_vth_v)
        shifted_vsn = max(0.0, vsn_v - dvth)
        shifted = _interp(shifted_vsn, self.lut[0], self.lut[1]) if self.lut else base
        return max(0.0, shifted * ion_scale)

    def read(self, row: int, col: int, t_hold_s: float = 0.0, vary: bool = True) -> float:
        return self.irbl_from_vsn(self.drifted_vsn(row, col, t_hold_s), vary=vary)

    def read_row(self, row: int, t_hold_s: float = 0.0, vary: bool = True) -> list[float]:
        return [self.read(row, col, t_hold_s, vary=vary) for col in range(self.cols)]


def demo() -> None:
    for model in ("full_swing", "vth_drop"):
        arr = IGZO256KArray("OHAD", write_model=model)
        for col in range(16):
            arr.write(0, col, col)
        currents = [arr.read(0, col, t_hold_s=0.0, vary=False) for col in range(16)]
        print(f"\nwrite_model={model}")
        for idx, current in enumerate(currents):
            print(
                f"state={idx:02d}, VSN={arr.vsn[0][idx]:.4f} V, "
                f"IRBL={current:.4e} A"
            )


if __name__ == "__main__":
    demo()
