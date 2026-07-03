# Controller for IGZO DRAM

Frontend RTL, verification collateral, and behavioral models for an SMIC 0.18um CMOS controller targeting monolithic 3D IGZO DRAM research.

This repository focuses on the controller/readout side of the project. It intentionally excludes foundry PDKs, proprietary IO libraries, Calibre/Pegasus rule decks, GDS databases, and private tapeout collateral.

## Design Concept

The current risk-reduced chip target is:

```text
2-bit/cell open-loop IGZO storage
two 2-bit slices rebuild one INT4 weight
INT4 = {high_2b, low_2b}
```

The analog side only needs robust four-level current sensing. Full INT4 reconstruction is handled digitally.

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

## Signoff Note

Final tapeout signoff still requires Calibre, or SMIC-approved Pegasus/Quantus rule decks. The SMIC Calibre TVF/SVRF decks used in the private project environment cannot be used directly as Pegasus/PVS PVL/PVTCL rule files.

## Public Release Hygiene

Do not commit:

- foundry PDKs,
- SP018N IO libraries,
- Calibre/Pegasus/Quantus rule decks,
- GDS/OASIS layout databases,
- private server paths or credentials,
- large generated backend outputs.

## License

See [LICENSE](LICENSE).
