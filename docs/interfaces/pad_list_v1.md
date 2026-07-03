# Pad List v1

This public pad list is a functional planning view. Final pad count, ordering, ESD type, and coordinates must be checked against the private pad-ring database and foundry IO collateral.

## Power

| Pad Group | Domain | Purpose |
|---|---|---|
| `DVDD18[*]` | 1.8 V | Digital core supply. |
| `DVSS[*]` | Ground | Digital ground. |
| `AVDD33[*]` | 3.3 V | Analog and selected IO supply. |
| `AVSS[*]` | Ground | Analog ground. |

## Digital Control and Debug

| Signal | Direction | Domain | Purpose |
|---|---|---|---|
| `SPI_CLK` | Input | 3.3 V IO | SPI clock. |
| `SPI_CSN` | Input | 3.3 V IO | Active-low SPI chip select. |
| `SPI_MOSI` | Input | 3.3 V IO | SPI data input. |
| `SPI_MISO` | Output | 3.3 V IO | SPI data output. |
| `CLK_CORE` | Input | 1.8 V | Digital core clock. |
| `RESET_N` | Input | 1.8 V | Active-low reset. |
| `SCAN_IN` | Input | 1.8 V | Scan-chain input. |
| `SCAN_OUT` | Output | 1.8 V | Scan-chain output. |
| `SCAN_EN` | Input | 1.8 V | Scan enable. |

## Analog Test and Monitor

| Signal | Direction | Domain | Purpose |
|---|---|---|---|
| `IRBL_EXT` | Analog input | 3.3 V analog | External SMU current injection for SA validation. |
| `IBIAS_MON` | Analog output | 3.3 V analog | Bias current monitor. |
| `IREF0_MON` | Analog output | 3.3 V analog | Reference current monitor. |
| `ANA_MON` | Analog output | 3.3 V analog | Analog mux monitor output. |

## BEOL Hooks

| Signal | Type | Purpose |
|---|---|---|
| `BEOL_PAD[01:12]` | Analog IO / landing | Future IGZO BEOL landing interface. |
| `ALIGN_MARK[1:4]` | Layout marker | BEOL alignment marks. |
| `DAISY[1:4]` | Monitor | Daisy-chain continuity checks. |
