# 数字规格文档 v1 | 2026-06-15

## 1. 顶层数字架构

数据路径（W4A8，INT8×INT8）：
  IGZO → SA → adc_decoder_2b → int4_rebuild → dequant_unit → bitserial_mac → accum26 → SPI

## 2. RTL 模块列表（共 15 个文件）

| 优先级 | 模块名 | 功能 | 接口宽度 |
|---|---|---|---|
| 1 | spi_slave.sv | SPI 从机接口 | 4-wire SPI（CLK/CSN/MOSI/MISO）|
| 1 | regfile.sv | 全 CSR 寄存器文件（含 CHIP_ID/SCALE_W 等）| 256×8bit |
| 2 | chip_id_csr.sv | CHIP_ID=0xA3, VERSION=0x30, SCRATCH R/W | — |
| 3 | act_regfile.sv | A8 激活寄存器文件（1024×8bit 双端口）| 10-bit addr, 8-bit data |
| 4 | adc_decoder_2b.sv | thermometer→binary 2-bit 解码 | 3-bit in, 2-bit out |
| 4 | int4_rebuild.sv | 2×2-bit → signed INT4 重建 | 4-bit in, 4-bit signed out |
| 5 | dequant_unit.sv | W4×scale→W8（per-layer/per-group/bypass）| 组合逻辑，≈30门 |
| 6 | bitserial_mac.sv | W8×A8 位串行 MAC（8-pass per row）| — |
| 6 | accum26.sv | 26-bit 有符号累加器 | —  |
| 7 | bist_ctrl.sv | BIST 控制逻辑 | — |
| 7 | row_seq.sv | 行序列控制（提供 group_id[2:0] 给 dequant）| 10-bit row addr |
| 8 | fsm_debug.sv | FSM_STATE/ERROR_CODE/STATUS_CLR | — |
| 9 | activation_shift_ctrl.sv | A8 bit-serial 提取控制 | — |
| 9 | scan_bypass_mux.sv | DFT 扫描链 mux | — |
| — | digital_top.sv | 顶层集成 | — |

## 3. 关键数值约束

### 26-bit 累加器溢出分析
  W8 范围：-128 ~ +127（signed 8-bit）
  A8 范围：-128 ~ +127（signed 8-bit）
  最大单次乘积：(-128) × (-128) = 16,384 = 2^14
  1024 行最坏累加：2^14 × 1024 = 2^24 = 16,777,216
  → 25-bit 范围 -2^24 到 +2^24-1 不够！
  → 必须用 signed 26-bit（-2^25 ~ +2^25-1）✅

### ROW_ADDR 宽度
  ROW_ADDR_L[7:0] + ROW_ADDR_H[1:0] = 10-bit（支持 0~1023）
  ⚠️ v2 版本只有 8-bit 是错的，已修正为 10-bit

### dequant_unit 精度
  tmp = signed(W4) × unsigned(SCALE_W)  ← 4×8=12bit，中间需 16-bit
  output = clamp(tmp, -128, 127)         ← signed 8-bit
  模式：per-layer(SCALE_W_G0), per-8-group(G0~G7), bypass(scale=1)

## 4. 综合目标

| 指标 | 目标 | 说明 |
|---|---|---|
| 时钟频率 | 50 MHz | 对应最大 IGZO 行访问速率 |
| 总面积 | < 0.08 mm²（含 act_regfile）| SMIC 0.18um |
| act_regfile 面积 | ~0.05 mm²（1024×8bit FF）| 可裁减至 256×8 节省 75% |
| Setup WNS | > 0（50 MHz）| Yosys+OpenSTA 验证 |
| 综合 Liberty | TT 25°C 1.8V | 迭代用；SS corner 确认 timing |

## 5. 仿真覆盖要求（Phase E3）

覆盖 17 个 test cases（见设计计划 §E3-RTL-2 表格），关键：
- act_load_all_zero / act_load_sequential
- dequant_min_max / dequant_clamp
- mac_w_pos_a_pos / mac_w_neg_a_neg / mac_w_neg_a_pos
- mac_zero_weight / mac_zero_activation
- mac_single_row / mac_scale1
- bitserial_pass_k / spi_autoinc / acc_readback_4byte

GLS: bit-exact 与 RTL 一致，reset 值与 CSR 表一致
