# Pad 列表 v1 | IGZO DRAM CMOS 芯片 | 2026-06-15

| # | Pad Name | Type | Domain | IO标准 | ESD | 用途 |
|---|----------|------|--------|--------|-----|------|
| 1-4 | DVDD18[1:4] | Supply | 1.8V | — | 内 | 数字核心供电 |
| 5-8 | DVSS[1:4] | Supply | GND | — | 内 | 数字地 |
| 9-12 | AVDD33[1:4] | Supply | 3.3V | — | 内 | 模拟供电 |
| 13-16 | AVSS[1:4] | Supply | GND | — | 内 | 模拟地 |
| 17 | SPI_CLK | Input | 3.3V | 3.3V CMOS | SP018 | SPI 时钟 |
| 18 | SPI_CSN | Input | 3.3V | 3.3V CMOS | SP018 | SPI 片选（低有效）|
| 19 | SPI_MOSI | Input | 3.3V | 3.3V CMOS | SP018 | SPI 数据输入 |
| 20 | SPI_MISO | Output | 3.3V | 3.3V CMOS | SP018 | SPI 数据输出 |
| 21 | SCAN_IN | Input | 1.8V | 1.8V CMOS | SP018 | 扫描链输入 |
| 22 | SCAN_OUT | Output | 1.8V | 1.8V CMOS | SP018 | 扫描链输出 |
| 23 | SCAN_EN | Input | 1.8V | 1.8V CMOS | SP018 | 扫描链使能 |
| 24 | CLK_CORE | Input | 1.8V | 1.8V CMOS | SP018 | 核心时钟输入 |
| 25 | RESET_N | Input | 1.8V | 1.8V CMOS | SP018 | 全局复位（低有效）|
| 26 | IRBL_EXT | Analog In | 3.3V | Analog | 专用模拟 | 外部电流注入（Bring-up L3）|
| 27 | IBIAS_MON | Analog Out | 3.3V | Analog | 专用模拟 | Bias 电流监测 |
| 28 | IREF0_MON | Analog Out | 3.3V | Analog | 专用模拟 | Iref[0]=1.089uA 监测 |
| 29 | ANA_MON | Analog Out | 3.3V | Analog | 专用模拟 | ANALOG_MUX_SEL 选通节点观测 |
| 30-41 | BEOL_PAD[01:12] | Analog I/O | 3.3V | Analog | BEOL规则 | BEOL landing matrix（IGZO连接）|
| 42-45 | ALIGN_MARK[1:4] | Layout | — | — | — | BEOL 对准标记 |
| 46-49 | DAISY[1:4] | Monitor | 3.3V | — | — | Daisy-chain 连通性验证 |
