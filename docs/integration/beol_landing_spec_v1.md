# BEOL Landing Specification v1

This document describes the public planning view for future BEOL IGZO integration. Final values require alignment with the process integration team and private layout collateral.

## Landing Interface

| Item | Planning Value | Note |
|---|---|---|
| Landing pads | `BEOL_PAD[01:12]` | Functional planning count. |
| Pad pitch | TBD | Must match BEOL process and alignment capability. |
| Opening size | TBD | Depends on final top-metal and passivation rules. |
| Metal layer | TBD | Must match the selected CMOS stack and BEOL process. |
| Alignment marks | `ALIGN_MARK[1:4]` | Used for BEOL overlay alignment. |

## Functional Allocation

| Pad Group | Function |
|---|---|
| `BEOL_PAD[01:04]` | Write bitline hooks, `WBL[0:3]`. |
| `BEOL_PAD[05:08]` | Read bitline hooks, `RBL[0:3]`. |
| `BEOL_PAD[09:10]` | Write wordline hooks, `WWL[0:1]`. |
| `BEOL_PAD[11:12]` | Read wordline hooks, `RWL[0:1]`. |

## Daisy-Chain Checks

Four daisy-chain monitor paths are reserved to validate BEOL continuity independently from the active readout path.

## Open Items

- Confirm IGZO TFT/contact minimum pitch.
- Confirm landing-pad metal layer and opening geometry.
- Confirm overlay/alignment requirement.
- Confirm continuity-test routing and pad assignment in the final pad ring.
