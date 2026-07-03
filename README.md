# Controller for IGZO DRAM

Frontend RTL, verification collateral, and behavioral models for an SMIC 0.18um CMOS controller targeting monolithic 3D IGZO DRAM research.

This repository focuses on the controller/readout side of the project. It excludes foundry PDKs, proprietary IO libraries, Calibre/Pegasus rule decks, GDS databases, and private tapeout collateral.

## What Is IGZO DRAM?

IGZO DRAM uses indium gallium zinc oxide thin-film transistors as memory access or storage devices. IGZO TFTs can provide very low off-state leakage, making them attractive for long-retention capacitorless or low-capacitance memory cells and for monolithic 3D integration above CMOS logic. In this project, the CMOS die acts as the controller/readout/test platform for future BEOL IGZO memory integration.

## Design Concept

The current risk-reduced chip target is:

```text
2-bit/cell open-loop IGZO storage
two 2-bit slices rebuild one INT4 weight
INT4 = {high_2b, low_2b}
```

The analog side only needs robust four-level current sensing. Full INT4 reconstruction is handled digitally.

## System Architecture

```mermaid
flowchart TD
    A["External SPI / debug pins"] --> B["SPI / CSR / control"]
    B --> C["Current emulator control"]
    B --> D["SA/DAC/analog macro trim/control"]
    B --> E["Low/high thermometer capture"]
    E --> F["2-bit thermometer decode"]
    F --> G["low_2b"]
    F --> H["high_2b"]
    G --> I["INT4 rebuild {high, low}"]
    H --> I
    I --> J["MAC / accumulate / status"]
    J --> K["SPI/status readback"]
```

## 2-bit/cell Targets

This validation chip uses four target read-current levels for the 2-bit/cell path:

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

## Repository Layout

```text
rtl/             SystemVerilog RTL for the digital controller
tb/              Directed Verilog testbenches
constraints/     Timing constraints for digital_top
models/          IGZO behavioral, retention, margin, and INT4 readout models
docs/            Architecture, register map, pad list, bring-up, and handoff docs
docs/zh/         Chinese detailed frontend design document
```

## Main RTL Blocks

```text
digital_top.sv
spi_slave.sv
regfile.sv
act_regfile.sv
adc_decoder_2b.sv
int4_rebuild.sv
dequant_unit.sv
bitserial_mac.sv
accum26.sv
row_seq.sv
bist_ctrl.sv
fsm_debug.sv
activation_shift_ctrl.sv
scan_bypass_mux.sv
```

## Key Interfaces

- SPI control and status register access
- BIST and debug status observation
- low/high 2-bit slice thermometer inputs from current-sense ADC macros
- INT4 rebuild path
- bit-serial MAC / accumulator path
- scan and bypass hooks for bring-up

## Documentation

Start with:

```text
docs/digital_specs_v1.md
docs/register_map_v1.md
docs/pad_list_v1.md
docs/bringup_procedure_v1.md
docs/zh/frontend_design_detail_zh_20260703.md
```

## Status

- RTL source tree and directed testbenches are included.
- Behavioral IGZO write/read, retention, ML-SA margin, and INT4 readout models are included.
- A separate internal handoff package contains backend Innovus evidence; that package is not fully mirrored here because it contains generated physical-design collateral.
- Foundry signoff is not included in this public repository.

## License

See [LICENSE](LICENSE).
