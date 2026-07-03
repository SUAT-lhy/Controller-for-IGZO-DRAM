# IGZO DRAM CMOS Test Chip 前端详细设计文档

版本：v1.0  
日期：2026-07-03  
工艺目标：SMIC 0.18um mixed-signal CMOS，SP018N 5MT pad ring  
文档范围：前端体系结构、数字/混合信号接口、行为模型、验证状态、后端交接边界  

---

## 1. 项目定位

本项目面向 Monolithic 3D IGZO DRAM 验证芯片。当前 CMOS 底片不包含真实 IGZO TFT 阵列，主要目标是在 SMIC 0.18um CMOS 上实现可测、可调、可复现的读出、控制、BIST、数字重构与 pad/BEOL landing 接口，为后续 BEOL IGZO 生长与阵列验证提供底座。

本版设计的主验收目标不是单 cell true 4-bit 可靠读出，而是降低首次流片风险：

```text
2-bit/cell open-loop storage
two 2-bit slices rebuild one INT4 weight
INT4 = {high_2b, low_2b}
```

该策略把模拟侧要求约束在四档电流读出，将完整 4-bit 权重组合放到数字域完成。这样可以避开单 cell 16 态在低电流/高电流端受 offset、mismatch、饱和和温漂影响过大的风险。

---

## 2. 本次 tapeout 范围

### 2.1 包含内容

| 模块 | 状态 | 说明 |
|---|---|---|
| SPI/CSR 前端 | 已有 MVT RTL / wrapper | 支持 CHIP_ID、scratch/control/status 级别访问 |
| 2-bit thermometer decode | 已有 RTL 行为 | 支持 `000/001/011/111` 到 `0/1/2/3` 映射 |
| INT4 rebuild | 已有 RTL 行为 | `int4_out = {high_sym, low_sym}` |
| Current emulator code | 已有 RTL 行为 | 将 high/low thermometer 组合成电流仿真控制码 |
| MAC accumulate smoke path | 已有 RTL 行为 | control bit 使能后累加 INT4 输出 |
| SA/ADC macro 接口 | black-box wrapper | 真实模拟宏由后端/模拟团队接入 |
| Reference DAC macro 接口 | black-box wrapper | 默认参考电流码用于 1.089/3.388/6.550 uA 目标 |
| BEOL landing macro 接口 | black-box wrapper | 包含 daisy-chain 与 Kelvin pad |
| SP018N pad wrapper | 已有 Verilog wrapper | 已映射 SP018N pad cell 名称 |
| 行为模型与脚本 | 已归档 | IGZO cell、retention、ML-SA margin、INT4 readout |
| 后端入口 | 已归档 | Innovus netlist、SDC、DEF、SPEF、timing/DRC 报告 |

### 2.2 不包含内容

| 内容 | 说明 |
|---|---|
| 真实 IGZO TFT/2T0C cell GDS | 后续 BEOL 生长，不在 CMOS GDS 中实现 |
| 真实 256Kb IGZO 阵列 | 当前只保留 landing/interface/test structures |
| 完整可签核 SRAM macro 替换 | `act_regfile` 在 Claude 主线中仍提示需 SRAM macro 替换 |
| Foundry signoff DRC/LVS/PEX | 当前 Calibre 不可用，Pegasus/Quantus 缺 SMIC 对应规则包 |
| 完整最终 RTL 源树 | 本地只保留 MVT RTL skeleton 与最终后端网表；完整 `digital_top.sv` 源树未在本机归档中找到 |

---

## 3. 系统架构

### 3.1 顶层数据流

```text
External SPI / debug pins
        |
        v
 SPI / CSR / control
        |
        +--> current emulator control
        |
        +--> SA/DAC/analog macro trim/control
        |
        +--> low/high thermometer capture
                         |
                         v
             2-bit thermometer decode
                         |
             +-----------+-----------+
             |                       |
          low_2b                  high_2b
             |                       |
             +-----------+-----------+
                         |
                         v
              INT4 rebuild {high, low}
                         |
                         v
               MAC / accumulate / status
                         |
                         v
                  SPI/status readback
```

### 3.2 混合信号边界

模拟域向数字域输出两个 3-bit thermometer code：

| 信号 | 宽度 | 方向 | 含义 |
|---|---:|---|---|
| `sa_low_therm` | 3 | analog -> digital | INT4 低 2-bit slice 读出 thermometer |
| `sa_high_therm` | 3 | analog -> digital | INT4 高 2-bit slice 读出 thermometer |

数字域输出或派生：

| 信号 | 宽度 | 方向 | 含义 |
|---|---:|---|---|
| `int4_out` | 4 | digital internal/debug | `{high_sym, low_sym}` |
| `current_emul_code` | 8 | digital -> analog/debug | `{2'b00, high_therm, low_therm}` |
| `mac_acc` | 26 | digital internal/debug | MVT 累加器输出 |
| `status` | 8 | digital -> SPI/status | bring-up 状态与观察点 |

---

## 4. 存储与读出规格

### 4.1 写入模型

当前主线写入模型为：

```text
VSN = WBL
```

原因：在 `WWL=2V` 且 `WBL<=1.5V` 时，写管导通直到 `WBL-SN` 的 `VDS` 接近 0；`VSN=WBL-Vth` 仅保留为 under-write 或 pessimistic corner。

### 4.2 2-bit/cell 四档目标

| Symbol | WBL/VSN target | Target IRBL |
|---:|---:|---:|
| 0 | 0.35 V | 0.254 uA |
| 1 | 0.60 V | 1.925 uA |
| 2 | 0.85 V | 4.850 uA |
| 3 | 1.10 V | 8.250 uA |

参考阈值：

| Threshold | Current |
|---|---:|
| T01 | 1.089 uA |
| T12 | 3.388 uA |
| T23 | 6.550 uA |

### 4.3 Thermometer code 定义

当前 RTL skeleton 使用如下映射：

| Thermometer | Symbol |
|---|---:|
| `3'b000` | 0 |
| `3'b001` | 1 |
| `3'b011` | 2 |
| `3'b111` | 3 |
| other | 0，当前 MVT skeleton 未单独输出 invalid flag |

注意：早期计划文档中也出现过 `000/100/110/111` 的 thermometer 约定。交接时必须以当前 RTL wrapper/testbench 中的 `000/001/011/111` 为准，或者在下一版 RTL 中显式冻结 bit ordering。

---

## 5. 数字前端设计

### 5.1 当前本地可交付 RTL

当前 clean 包中可读 RTL 为 MVT skeleton：

```text
rtl/igzo_e3_top.v
rtl/d0_adder_smoke.v
```

`igzo_e3_top` 端口：

| 端口 | 方向 | 宽度 | 说明 |
|---|---|---:|---|
| `clk` | input | 1 | 1.8V core clock |
| `rst_n` | input | 1 | active-low reset |
| `spi_sclk` | input | 1 | SPI clock |
| `spi_csn` | input | 1 | SPI chip select |
| `spi_mosi` | input | 1 | SPI MOSI |
| `spi_miso` | output | 1 | SPI MISO |
| `sa_low_therm` | input | 3 | low slice thermometer |
| `sa_high_therm` | input | 3 | high slice thermometer |
| `int4_out` | output reg | 4 | rebuilt INT4 |
| `current_emul_code` | output reg | 8 | emulator/debug code |
| `mac_acc` | output reg | 26 | MVT accumulator |
| `status` | output reg | 8 | status/debug |

### 5.2 CSR/SPI 行为

MVT skeleton 中 SPI 行为是 bring-up 级别：

| 寄存器/行为 | 当前实现 |
|---|---|
| `CHIP_ID` | localparam `8'h49` |
| `scratch` | SPI 收满 8 bit 后写入 |
| `ctrl` | 与 scratch 同步写入 |
| `ctrl[0]` | 使能 `mac_acc <= mac_acc + int4_out` |
| `ctrl[1]` | 选择 SPI 读出 `scratch`，否则读出 `CHIP_ID` |

这不是最终复杂 CSR map。Claude 主线报告中提到过 `register_map_v1.md` 和 0x00-0x58 CSR，但完整文件未在本地归档中找到。后续若从 AutoDL 或原开发仓库恢复完整 `digital_top.sv` 源树，应以完整 CSR map 为准。

### 5.3 后端当前使用网表

后端当前可用的最终数字网表是 Innovus P&R 后导出的：

```text
netlist/digital_top_innovus.v
constraints/digital_top.sdc
backend_reference/digital_top_innovus.def
backend_reference/digital_top_innovus.spef
```

该网表来自 Cadence Innovus 重做 P&R，已解决 OpenROAD M1/VIA12 问题。

---

## 6. 顶层 wrapper 与 pad 接口

### 6.1 SP018N wrapper

当前 clean 包提供：

```text
top_wrapper/igzo_testchip_top_sp018n.v
```

该文件将测试芯片外部 pad 抽象连接到 SP018N pad cell：

| 类型 | Pad/Cell 示例 |
|---|---|
| 数字输入 | `PINN` |
| 数字输出 | `PO8N` |
| 模拟 pad | `PANA1APN` |
| 电源 pad | `PVDD1N`, `PVSS1N` |

顶层主要 pad：

| Pad | 方向 | 用途 |
|---|---|---|
| `PAD_CLK_IN` | input | core/test clock |
| `PAD_RESET_N` | input | reset |
| `PAD_SPI_SCLK` | input | SPI clock |
| `PAD_SPI_CSN` | input | SPI chip select |
| `PAD_SPI_MOSI` | input | SPI MOSI |
| `PAD_SPI_MISO` | output | SPI MISO |
| `PAD_SCAN_IN/OUT` | input/output | scan/debug chain placeholder |
| `PAD_BIST_DONE/FAIL` | output | BIST status placeholder |
| `PAD_IIN_FORCE0/1` | analog inout | external current injection force |
| `PAD_IIN_SENSE0/1` | analog inout | external current injection sense |
| `PAD_IREF01/12/23` | analog inout | reference current observe/trim |
| `PAD_BEOL_DAISY_IN/OUT` | analog inout | BEOL daisy-chain |
| `PAD_LANDING_KELVIN_P/N` | analog inout | landing pad Kelvin test |
| `PAD_WWL/WBL/RBL_MON` | analog inout | array/driver monitor |

### 6.2 模拟宏黑盒

当前 wrapper 中的模拟宏仍为 black-box：

| Macro | 说明 |
|---|---|
| `SA_ADC_2BIT_MACRO` | 2-bit current sense ADC |
| `CURRENT_REF_DAC_MACRO` | reference current DAC |
| `BEOL_LANDING_MATRIX_MACRO` | BEOL landing/daisy-chain macro |

后端/模拟团队需要提供对应 schematic/CDL/GDS/LEF 或 black-box 策略，并在 LVS 中处理一致性。

---

## 7. 行为模型与验证

### 7.1 行为模型文件

```text
models/behavioral/igzo_256k_virtual_array.py
models/params/igzo_params_nominal.json
models/params/igzo_params_OHAD.json
models/params/igzo_params_pilot.json
models/scripts/cell_transient_sim.py
models/scripts/retention_estimate.py
models/scripts/mlsa_margin_analysis.py
models/scripts/int4_readout_model.py
```

### 7.2 已完成验证摘要

| 阶段 | 结果 |
|---|---|
| PhaseB Python transient | write/hold/read 行为与 ngspice behavior cell 基本一致 |
| Retention | OHAD / ultra-low leakage corner 才支持长保持目标 |
| ML-SA margin | 单 cell 16 态不作为首片可靠目标 |
| E3 RTL smoke | thermometer decode、INT4 rebuild、current emulator、MAC accumulate PASS |
| E4 mixed smoke | 16 种 low/high slice 组合 PASS |
| Innovus P&R | internal DRC clean；setup/hold timing pass |

### 7.3 当前关键验证数字

Innovus re-P&R 后：

```text
Internal DRC: No DRC violations were found
Setup WNS: 8.743 ns, TNS: 0.000 ns
Hold  WNS: 0.126 ns, TNS: 0.000 ns
Density: 43.087%
```

剩余 connectivity note：

```text
501 unconnected VNW terminals.
All are NW-layer well abstraction pins.
No ordinary signal, VDD, or VSS open/short entries were reported.
```

这需要在最终 Calibre LVS 前结合标准单元 welltap/井连接策略确认。

---

## 8. 后端交接说明

### 8.1 推荐后端入口

对数字 core 后端，优先使用：

```text
netlist/digital_top_innovus.v
constraints/digital_top.sdc
backend_reference/digital_top_innovus.def
backend_reference/digital_top_innovus.spef
```

对 top-level wrapper/pad integration，参考：

```text
top_wrapper/igzo_testchip_top_sp018n.v
```

### 8.2 不应作为 signoff 的内容

| 文件/类别 | 限制 |
|---|---|
| `rtl/igzo_e3_top.v` | MVT skeleton，适合解释功能，不等同完整最终 `digital_top.sv` 源树 |
| `tb/*.v` | directed smoke test，非完整 UVM/regression |
| `models/*.py` | 行为建模与风险分析，不替代 SPICE signoff |
| Innovus internal DRC | 可说明 P&R clean，但不能替代 SMIC/Calibre signoff DRC |

### 8.3 tapeout 前必须补齐

1. 恢复或重新归档完整前端 RTL 源树，包括报告中列出的 `spi_slave/regfile/act_regfile/adc_decoder_2b/int4_rebuild/dequant_unit/bitserial_mac/accum26/row_seq/bist_ctrl/fsm_debug/activation_shift_ctrl/scan_bypass_mux/digital_top`。
2. 冻结 SPI CSR/register map，并与 firmware bring-up 脚本一致。
3. 冻结 thermometer bit ordering，并补 invalid thermometer flag。
4. 明确 `act_regfile` 是 FF 实现还是 SRAM macro 替换。
5. 完成 gate-level simulation 或至少 reset/SPI/BIST smoke GLS。
6. 获得 Calibre 或 SMIC Pegasus/Quantus 官方规则包，完成 full-chip DRC/LVS/PEX。

---

## 9. GitHub README 与详细设计文档的区别

GitHub `README.md` 不应等同于本详细设计文档。二者目标不同：

| 文档 | 读者 | 内容深度 |
|---|---|---|
| 中文详细设计文档 | 内部前端/后端/模拟团队 | 规格、接口、限制、交接边界、风险 |
| GitHub README | 外部读者/评审/开源仓库访问者 | 项目概览、目录结构、可运行内容、当前状态、免责声明 |

README 应短一些，避免放入 PDK、foundry 私有信息、完整 tapeout 细节和不适合公开的路径/凭据。

---

## 10. Clean 交接包路径

```text
frontend_handoff_clean_20260703/
```

建议后端团队从该目录开始阅读：

1. `README.md`
2. `docs/前端详细设计文档_20260703.md`
3. `constraints/digital_top.sdc`
4. `netlist/digital_top_innovus.v`
5. `top_wrapper/igzo_testchip_top_sp018n.v`
6. `backend_reference/`
