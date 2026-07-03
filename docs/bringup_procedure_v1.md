# Bring-up 操作流程 v1 | 2026-06-15

## Level 0 — SPI 数字通信验证（不涉及任何模拟电路）

**目标**：确认 SPI 通路正常，芯片可通信

**操作序列**：
1. SPI_CSN=0，发送 READ 命令 + addr=0x00
2. 读回 CHIP_ID，期望 **0xA3**
3. 读 VERSION (0x01)，期望 **0x30**（major=3, minor=0）
4. 写 SCRATCH (0x02) = 0xA5，读回期望 **0xA5**（bit-exact）

**成功判据**：CHIP_ID=0xA3, VERSION=0x30, SCRATCH 写读一致
**失败处置**：检查 SPI CLK/MOSI/MISO 时序；用 scan chain bypass 验证寄存器

---

## Level 1 — 纯数字 BIST/MAC bypass（不经过 SA）

**目标**：验证数字逻辑和 MAC 路径正确

**操作序列**：
1. spi_write(0x50, 0x00)          # SCALE_MODE=per-layer
2. spi_write(0x51, 0x10)          # SCALE_W_G0=16
3. spi_write(0x04, 0x12)          # bypass_sa=1, act_load_mode=1
4. spi_write(0x40, 0x00); spi_write(0x41, 0x00); spi_write(0x43, 0x01)
5. for i in range(n_rows): spi_write(0x42, a8[i])  # 批量写 act_regfile
6. spi_write(0x04, 0x94)          # bypass_sa=1, start=1
7. while not (spi_read(0x10) & 0x80): pass  # 等 mac_done
8. acc_raw = read_acc_4byte()
9. acc_int32 = sign_extend_26bit(acc_raw)

**成功判据**：acc_int32 == golden_model(W8_pattern, a8_loaded)，**bit-exact**
**失败处置**：scan chain 逐模块验证；检查 CLK_DIV 配置

---

## Level 2 — 片内电流模拟器 → SA → ADC 原码

**目标**：验证模拟 SA 路径，不需要 IGZO

**操作序列**：
1. spi_write(0x0E, 0x40)          # int_dac_en=1, emul_code=0（最小电流）
2. therm = spi_read(0x14)          # ADC_RAW_THERM，期望 0x00（电流 < Iref[0]）
3. spi_write(0x0E, 0x43)          # emul_code=3（~Iref[0]+）
4. therm = spi_read(0x14)          # 期望 0x01（001 thermometer，Level 1）
5. spi_write(0x0E, 0x7F)          # emul_code=最大
6. therm = spi_read(0x14)          # 期望 0x07（111 thermometer，Level 3）

**成功判据**：4 个 emul_code 档位 thermometer 码与 golden 一致（00/01/11/111）
**失败处置**：读 SA_DEBUG(0x15) 逐路检查；调整 DAC_CODE_DIRECT(0x16) 校准

---

## Level 3 — 外部 SMU 注入 → SA → INT4 → MAC → ACC

**目标**：完整模拟+数字链路验证，不需要 IGZO

**操作序列**：
1. 连接外部 SMU 到 IRBL_EXT pad
2. spi_write(0x0E, 0x80)          # ext_inject=1
3. SMU 设置 I = 0.254 uA（最低档）
4. 读 ADC_RAW_THERM(0x14)，期望 0x00
5. 配置 SCALE_W 和 act_regfile，触发 MAC
6. 读 ACC，与 golden_model 比对

**成功判据**：ACC = golden_model(SMU 电流对应的 INT4, act_regfile)
**失败处置**：先测 IREF0_MON pad 确认偏置正常；用 ANALOG_MUX_SEL 选通观测

---

## Level 4 — IGZO BEOL 堆叠完整链路（微电子所完成 BEOL 后）

**成功判据分三层**：
- L4-a：SA 读出 BER < 10^-3
- L4-b：current emulator 注入场景 MAC==golden（bit-exact）
- L4-c：真实 IGZO 场景，cosine similarity 与 CPU float 参考一致
