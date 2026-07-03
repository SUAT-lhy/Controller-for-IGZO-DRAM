# Bring-up Procedure v1

This bring-up plan moves from pure digital checks to analog-sense validation. Each level should be completed before moving to the next.

## Level 0: SPI Link

Goal: confirm that the chip can be addressed and read over SPI.

1. Read `CHIP_ID` at `0x00`; expect `0xA3`.
2. Read `VERSION` at `0x01`; expect `0x30`.
3. Write `0xA5` to `SCRATCH` at `0x02`.
4. Read `SCRATCH`; expect `0xA5`.

Pass criterion: identity and scratch readback are bit-exact.

## Level 1: Digital Bypass / MAC

Goal: validate the digital controller and MAC path without analog sensing.

1. Configure scale mode and activation data.
2. Enable SA bypass mode through `CTRL`.
3. Start a short MAC run.
4. Poll `STATUS.mac_done`.
5. Read `ACC_OUT_0` through `ACC_OUT_3`.
6. Compare the signed accumulator value with a software golden model.

Pass criterion: accumulator readback matches the expected digital result.

## Level 2: Current Emulator to Sense Capture

Goal: validate internal current generation, sense thresholds, and thermometer capture without external IGZO hardware.

1. Enable the current emulator.
2. Sweep representative emulator codes from low to high.
3. Read `ADC_RAW_THERM`.
4. Confirm monotonic thermometer behavior.
5. Check `READ_DATA` for decoded 2-bit symbols.

Pass criterion: increasing emulator current maps to increasing thermometer/decode outputs.

## Level 3: External Current Injection

Goal: validate the analog receive path using an external SMU or precision current source.

1. Connect external current source to `IRBL_EXT`.
2. Enable external injection mode.
3. Inject currents around each target level and threshold.
4. Read thermometer and decoded values.
5. Run a short MAC/readback sequence using injected values.

Pass criterion: decoded symbols and downstream accumulator behavior match expected current regions.

## Level 4: BEOL IGZO Path

Goal: validate the final IGZO-linked path after BEOL integration.

1. Confirm BEOL daisy-chain continuity.
2. Measure basic leakage and read-current distributions.
3. Program/read the four target states.
4. Run decoded readback into the INT4 rebuild path.

Pass criterion: the read path is stable enough to separate the four target states with acceptable margin for the experiment.
