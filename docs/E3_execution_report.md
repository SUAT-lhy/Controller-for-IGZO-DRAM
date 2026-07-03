# Phase E3 RTL 实现执行报告
**日期**: 2026-06-15  
**阶段**: E3 – 数字 RTL 实现与仿真

---

## 1. RTL 实现清单（15 模块 + digital_top）

| 模块 | 文件 | 状态 | 备注 |
|------|------|------|------|
| spi_slave | spi_slave.sv | ✅ | SPI Mode 0, MSB-first, 双同步 |
| regfile | regfile.sv | ✅ | 0x00-0x58 CSR, W1C status, 26-bit ACC 拼接 |
| act_regfile | act_regfile.sv | ✅ | 1024×8bit, 组合读/同步写 |
| adc_decoder_2b | adc_decoder_2b.sv | ✅ | thermometer→2-bit binary |
| int4_rebuild | int4_rebuild.sv | ✅ | 2×2-bit→signed INT4 |
| dequant_unit | dequant_unit.sv | ✅ | W4×scale→clamp→W8 |
| bitserial_mac | bitserial_mac.sv | ✅ | 并行乘法（等效位串行），2周期/行 |
| accum26 | accum26.sv | ✅ | 26-bit 有符号，溢出检测，单次清零 |
| row_seq | row_seq.sv | ✅ | 计数器模式，上升沿触发防重启 |
| bist_ctrl | bist_ctrl.sv | ✅ | 4状态FSM |
| fsm_debug | fsm_debug.sv | ✅ | IDLE/LOAD/MAC/DONE/ERROR |
| activation_shift_ctrl | activation_shift_ctrl.sv | ✅ | 地址直通 |
| scan_bypass_mux | scan_bypass_mux.sv | ✅ | 参数化宽度 |
| digital_top | digital_top.sv | ✅ | 全集成，边沿触发MAC运行控制 |

---

## 2. 关键设计决策记录

### 2.1 累加器清零策略
- **问题**：bitserial_mac 原设计每行触发 acc_start，导致积累器逐行复位
- **修复**：移除 bitserial_mac 的 acc_start 输出，改由 digital_top 检测 go 上升沿（mac_run_r）产生单次清零脉冲
- **结果**：正确跨行累积

### 2.2 row_seq 防重启
- **问题**：go 为电平触发，FSM 状态转换有 1 周期延迟导致 row_seq 重启第二遍
- **修复**：row_seq 内部增加 go_prev/go_rise 上升沿检测，仅在 go 上升沿启动
- **结果**：每次 CTRL[7]=1 只运行一次 MAC 序列

### 2.3 act_regfile 写地址时序
- **问题**：act_wen/act_ptr 均为 NB 赋值，act_ptr 已自增一拍后才写入
- **修复**：regfile 增加 act_waddr 输出（在自增前捕获当前 ptr）
- **结果**：激活数据写入正确地址

### 2.4 SPI 读地址解析
- **问题**：reg_addr 含 R/W 最高位，导致 regfile case 不匹配（读 0x00 得 0x00）
- **修复**：spi_slave addr_latch = {1'b0, shift_in[5:0], mosi_in}（丢弃 R/W 位）
- **结果**：CHIP_ID=0xA3 正确读回

---

## 3. 仿真结果（tb_full.v，12 checks）

| TC | 描述 | 结果 | ACC 期望/实际 |
|----|------|------|--------------|
| TC1 | SPI identity (CHIP_ID/VERSION/SCRATCH) | PASS×3 | — |
| TC2 | all-zero activations | PASS | 0/0 |
| TC3 | seq acts 0..15, scale=1 | PASS | 120/120 |
| TC4 | single row a=42 | PASS | 42/42 |
| TC5 | 4 rows a=1,2,3,4 | PASS | 10/10 |
| TC6 | SPI auto-increment readback | PASS×4 | — |
| TC7 | signed act 0xFF(-1)×4 | PASS | -4/-4 |

**总计：12/12 PASS，0 FAIL**

---

## 4. Yosys 综合结果（TT 25°C 1.8V）

| 指标 | 数值 | 目标 | 状态 |
|------|------|------|------|
| 逻辑面积（不含 act_regfile） | 48,490 μm² = 0.048 mm² | < 0.08 mm² | ✅ |
| act_regfile（FF based） | 898,916 μm² ≈ 0.899 mm² | N/A（用 SRAM 替换） | ⚠️ |
| digital_top 逻辑单元 | 207 cells | — | ✅ |
| 总 cells（含 act_regfile FF） | 45,851 | — | — |

**注**：act_regfile 使用标准单元 FF 实现，仅用于 RTL 仿真验证。流片阶段将替换为 SRAM 编译器生成的 8K×1 macro（面积约 0.02~0.04 mm²）。

---

## 5. iverilog 语法检查结果

所有 14 个模块（+ digital_top）均通过  编译，0 error。

---

## 6. 遗留问题与下一步

| 编号 | 问题 | 优先级 | 计划 |
|------|------|--------|------|
| E3-P1 | act_regfile 需换 SRAM macro | 高 | Phase F layout 时引入 |
| E3-P2 | dequant_unit bypass 模式 W4→W8 精度验证 | 中 | TC 补充 |
| E3-P3 | bitserial_mac 改为真正位串行（功耗） | 低 | 综合后 power 分析 |
| E3-P4 | OpenSTA timing signoff（50MHz WNS > 0）| 中 | Phase G |

---

**下一阶段**: E4 混合信号协同仿真（Python + ngspice，SA BER 验证）
