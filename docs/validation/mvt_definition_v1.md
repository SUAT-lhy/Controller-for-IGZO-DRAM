# Minimum Viable Tapeout Feature Set v1

The MVT definition separates must-have silicon validation features from features that may be reduced if area, schedule, or signoff risk increases.

## Must Have

| Feature | Reason |
|---|---|
| SPI interface with `CHIP_ID` and `SCRATCH` | Confirms first-contact digital communication after silicon return. |
| CSR status and debug registers | Required for bring-up visibility and failure isolation. |
| Digital MAC bypass mode | Validates the controller datapath without relying on analog sensing. |
| Current emulator | Exercises the sense path without a real IGZO stack. |
| 2-bit sense capture and decode | Core validation target of the chip. |
| External current injection pad | Allows SMU-driven analog validation. |
| BEOL landing hooks and daisy chains | Enables later IGZO integration and continuity checks. |
| Scan/bypass hooks | Improves debug access if normal control flow fails. |

## Reducible

| Feature | Possible Reduction | Impact |
|---|---|---|
| Activation storage depth | Reduce from 1024 rows to a smaller validated depth. | Lowers area, reduces MAC test coverage length. |
| Per-group scale values | Keep per-layer scale only. | Reduces quantization flexibility. |
| Full-row MAC run length | Validate 4, 16, 64, or 256 rows first. | Shortens bring-up and debug loops. |

## Do Not Remove

- `CHIP_ID`
- `SCRATCH`
- Status/error readback
- BIST or bypass mode
- Current emulator control
- External current injection path
- Analog monitor mux
- Scan/debug hooks

## Bring-up Milestones

| Milestone | Expected Timing | Pass Criterion |
|---|---|---|
| Level 0 | Silicon day 1 | SPI identity and scratch register pass. |
| Level 1 | Day 1 to 2 | Digital bypass MAC matches golden model. |
| Level 2 | Day 2 to 3 | Current emulator produces expected thermometer codes. |
| Level 3 | Day 3 to 5 | External injection path matches expected decoded/current behavior. |
| Level 4 | After BEOL integration | IGZO-linked readout path is measurable and repeatable. |
