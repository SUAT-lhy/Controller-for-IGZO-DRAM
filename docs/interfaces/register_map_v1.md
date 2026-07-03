# Register Map v1

The controller exposes an 8-bit address, 8-bit data SPI register interface. Multi-byte values are read or written one byte at a time.

## System Registers

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x00 | `CHIP_ID` | RO | 0xA3 | First bring-up identity read. |
| 0x01 | `VERSION` | RO | 0x30 | Design version field. |
| 0x02 | `SCRATCH` | RW | 0x00 | SPI write/read sanity check. |
| 0x03 | `CLK_DIV` | RW | 0x04 | Internal clock divider control. |

## Control and Configuration

| Address | Name | Access | Description |
|---:|---|---|---|
| 0x04 | `CTRL` | RW | Start, mode, SA bypass, CDS enable, BIST enable, activation load, soft reset. |
| 0x05 | `ROW_ADDR_L` | RW | Row address bits [7:0]. |
| 0x06 | `ROW_ADDR_H` | RW | Row address bits [9:8]. |
| 0x07 | `N_ROWS_L` | RW | Row count bits [7:0]. |
| 0x08 | `N_ROWS_H` | RW | Row count bits [9:8]. |
| 0x09 | `TRIM_DAC0` | RW | Reference trim for T01. |
| 0x0A | `TRIM_DAC1` | RW | Reference trim for T12. |
| 0x0B | `TRIM_DAC2` | RW | Reference trim for T23. |
| 0x0C | `TIMING` | RW | Integration and settling timing selection. |
| 0x0D | `LOAD_CFG` | RW | Bitline/wordline load-bank configuration. |
| 0x0E | `EMULATOR` | RW | Internal current emulator and external injection control. |
| 0x0F | `BIST_CFG` | RW | BIST pattern and sweep configuration. |

## Status and Debug

| Address | Name | Access | Description |
|---:|---|---|---|
| 0x10 | `STATUS` | RO | MAC done, SA error, BIST pass, activation-loaded, interrupt. |
| 0x11 | `FSM_STATE` | RO | Encoded controller state. |
| 0x12 | `ERROR_CODE` | RO | Sticky error code. |
| 0x13 | `STATUS_CLR` | W1C | Clear selected status bits. |
| 0x14 | `ADC_RAW_THERM` | RO | Raw 3-bit thermometer result. |
| 0x15 | `SA_DEBUG` | RO | Selected sense/debug observation value. |
| 0x16 | `DAC_CODE_DIRECT` | RW | Manual DAC override for calibration. |
| 0x17 | `ANALOG_MUX_SEL` | RW | Analog monitor mux selection. |
| 0x18 | `READ_DATA` | RO | Decoded 2-bit symbol. |
| 0x19 | `BIST_RESULT` | RO | BIST done/pass and fail hint. |
| 0x1A | `SCAN_CTRL` | RW | Scan mode and scan enable. |

## Accumulator Readback

| Address | Name | Access | Description |
|---:|---|---|---|
| 0x20 | `ACC_OUT_0` | RO | Accumulator byte 0, least significant byte. |
| 0x21 | `ACC_OUT_1` | RO | Accumulator byte 1. |
| 0x22 | `ACC_OUT_2` | RO | Accumulator byte 2. |
| 0x23 | `ACC_OUT_3` | RO | Accumulator byte 3, includes sign bits. |

## Activation Register Access

| Address | Name | Access | Description |
|---:|---|---|---|
| 0x40 | `ACT_ADDR_L` | RW | Activation memory pointer bits [7:0]. |
| 0x41 | `ACT_ADDR_H` | RW | Activation memory pointer bits [9:8]. |
| 0x42 | `ACT_DATA` | RW | Activation data port. |
| 0x43 | `ACT_CTRL` | RW | Activation access control, including auto-increment. |

## Scale / Dequantization

| Address | Name | Access | Description |
|---:|---|---|---|
| 0x50 | `SCALE_MODE` | RW | Per-layer, per-group, or bypass scaling mode. |
| 0x51 | `SCALE_W_G0` | RW | Scale value for group 0 or global scale. |
| 0x52 | `SCALE_W_G1` | RW | Scale value for group 1. |
| 0x53 | `SCALE_W_G2` | RW | Scale value for group 2. |
| 0x54 | `SCALE_W_G3` | RW | Scale value for group 3. |
| 0x55 | `SCALE_W_G4` | RW | Scale value for group 4. |
| 0x56 | `SCALE_W_G5` | RW | Scale value for group 5. |
| 0x57 | `SCALE_W_G6` | RW | Scale value for group 6. |
| 0x58 | `SCALE_W_G7` | RW | Scale value for group 7. |
