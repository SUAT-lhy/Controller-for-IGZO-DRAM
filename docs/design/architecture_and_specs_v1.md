# Architecture and Specification v1

## Scope

This document merges the previous analog and digital specification notes into one system-level specification. Keeping them together makes the chip intent clearer: the analog front-end only needs robust four-level current sensing, while the digital controller performs 2-bit decoding, INT4 reconstruction, scaling, MAC accumulation, and readback.

## System Path

```text
IGZO / current emulator / external current injection
    -> current sense and reference thresholds
    -> low/high thermometer capture
    -> 2-bit decode for each slice
    -> INT4 rebuild: {high_2b, low_2b}
    -> optional dequantization
    -> bit-serial MAC and 26-bit accumulator
    -> SPI status/readback
```

## Memory-State Target

The risk-reduced validation target is 2-bit/cell open-loop IGZO storage. One sensed cell or slice maps to four current levels and therefore one 2-bit symbol.

| Symbol | WBL/VSN target | Target IRBL |
|---:|---:|---:|
| 0 | 0.35 V | 0.254 uA |
| 1 | 0.60 V | 1.925 uA |
| 2 | 0.85 V | 4.850 uA |
| 3 | 1.10 V | 8.250 uA |

Reference thresholds:

| Threshold | Current |
|---|---:|
| T01 | 1.089 uA |
| T12 | 3.388 uA |
| T23 | 6.550 uA |

## INT4 Reconstruction

Two 2-bit slices rebuild one signed or unsigned 4-bit weight, depending on the selected interpretation in the downstream MAC path.

```text
low_2b  = lower two bits
high_2b = upper two bits

INT4[3:0] = {high_2b[1:0], low_2b[1:0]}
          = low_2b + 4 * high_2b
```

This reduces first-silicon risk because the analog macro must separate four current bands per slice rather than sixteen bands in a single cell.

## Analog Front-End Requirements

| Block | Requirement |
|---|---|
| Current sensing | Resolve four read-current bands with margin across expected PVT and mismatch conditions. |
| Reference thresholds | Provide T01, T12, and T23 references with trim capability. |
| Current emulator | Generate internal test currents for bring-up without a real IGZO stack. |
| External injection | Allow SMU-driven current injection for direct SA/ADC validation. |
| Monitor hooks | Expose bias/reference/selected analog nodes through monitor pads or mux paths. |
| Level shifting | Support 1.8 V digital control and 3.3 V analog/IO domains where needed. |

## Digital Controller Requirements

| Block | Role |
|---|---|
| `spi_slave.sv` | SPI control and status transport. |
| `regfile.sv` | CSR decode, control, status, debug, and readback registers. |
| `adc_decoder_2b.sv` | Convert thermometer sense result into a 2-bit symbol. |
| `int4_rebuild.sv` | Concatenate low/high 2-bit symbols into an INT4 value. |
| `dequant_unit.sv` | Apply scale or bypass mode before MAC input. |
| `bitserial_mac.sv` | Multiply/reduce activation and reconstructed weight data. |
| `accum26.sv` | Hold signed 26-bit accumulation result. |
| `row_seq.sv` | Generate row iteration and group selection. |
| `bist_ctrl.sv` | Support internal test modes. |
| `fsm_debug.sv` | Provide state and error visibility. |
| `activation_shift_ctrl.sv` | Feed activation data into the MAC path. |
| `scan_bypass_mux.sv` | Provide scan/bypass support for silicon debug. |
| `digital_top.sv` | Integrate the controller datapath and CSR-visible control. |

## Numeric Bounds

- Activation input: signed 8-bit.
- Rebuilt weight path: INT4 expanded or scaled before MAC use.
- Worst-case single multiply scale is kept within the chosen MAC implementation.
- Accumulator width: signed 26-bit, sized for up to 1024 rows with margin.
- Row address width: 10-bit, supporting 0 to 1023.

## Timing and Implementation Targets

| Item | Target |
|---|---|
| Digital clock | 50 MHz nominal target. |
| Core voltage | 1.8 V digital domain. |
| Analog/IO voltage | 3.3 V domain where required. |
| Bring-up priority | SPI, CSR, bypass MAC, current emulator, SA decode, external injection. |
| Signoff note | Final foundry signoff requires qualified DRC/LVS/PEX decks and is outside this public repository. |
