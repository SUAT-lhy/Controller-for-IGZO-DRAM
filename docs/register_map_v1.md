# IGZO DRAM CMOS 芯片寄存器映射 v1
**SPI 接口**: 8-bit addr, 8-bit data | 日期: 2026-06-15  
**总地址**: 0x00–0x58（直接寻址）+ act_regfile 间接扩展

---

## 0x00–0x03 系统/身份识别（Bring-up Level 0 必需）

| Addr | Name | Fields | Reset | Access | 说明 |
|------|------|--------|-------|--------|------|
| 0x00 | CHIP_ID | [7:0]=0xA3 | 0xA3 | R/O | 回片第一读，确认 SPI 通路 |
| 0x01 | VERSION | [7:4]:major=3 [3:0]:minor=0 | 0x30 | R/O | 设计版本 v3.0 |
| 0x02 | SCRATCH | [7:0] | 0x00 | R/W | SPI 连通测试（写 0xA5 读回 0xA5）|
| 0x03 | CLK_DIV | [7:0]:div | 0x04 | R/W | SPI/内部时钟分频（默认 ÷4, 200MHz→50MHz）|

## 0x04–0x0F 控制与配置

| Addr | Name | Fields | Reset | Access | 说明 |
|------|------|--------|-------|--------|------|
| 0x04 | CTRL | [7]:start [6:5]:mode [4]:bypass_sa [3]:cds_en [2]:bist_en [1]:act_load_mode [0]:sw_rst | 0x00 | R/W | 主控; bypass_sa=1→数字 BIST 直通 MAC |
| 0x05 | ROW_ADDR_L | [7:0]:row_addr[7:0] | 0x00 | R/W | 行地址低 8 位 |
| 0x06 | ROW_ADDR_H | [1:0]:row_addr[9:8] | 0x00 | R/W | 行地址高 2 位（共 10-bit，0~1023）|
| 0x07 | N_ROWS_L | [7:0]:n_rows[7:0] | 0x00 | R/W | MAC 行数低字节 |
| 0x08 | N_ROWS_H | [1:0]:n_rows[9:8] | 0x00 | R/W | MAC 行数高 2 位 |
| 0x09 | TRIM_DAC0 | [7:4]:coarse [3:0]:fine | 0x88 | R/W | Iref[0]=1.089uA trim |
| 0x0A | TRIM_DAC1 | [7:4]:coarse [3:0]:fine | 0x88 | R/W | Iref[1]=3.388uA trim |
| 0x0B | TRIM_DAC2 | [7:4]:coarse [3:0]:fine | 0x88 | R/W | Iref[2]=6.550uA trim |
| 0x0C | TIMING | [7:4]:t_int_sel [3:0]:t_settle_sel | 0x11 | R/W | SA 积分/settling 时间选择 |
| 0x0D | LOAD_CFG | [7:6]:load_sel [5:4]:bl_cap_sel [3:2]:wl_cap_sel | 0x00 | R/W | BL/WL 负载 bank 配置 |
| 0x0E | EMULATOR | [7]:ext_inject [6]:int_dac_en [5:0]:emul_code | 0x00 | R/W | 片内电流模拟器（Bring-up L2）|
| 0x0F | BIST_CFG | [7:4]:pattern [3:0]:sweep_range | 0x00 | R/W | BIST 图案与扫描范围 |

## 0x10–0x1F 状态与调试（Bring-up Level 1-3 必需）

| Addr | Name | Fields | Reset | Access | 说明 |
|------|------|--------|-------|--------|------|
| 0x10 | STATUS | [7]:mac_done [6]:sa_error [5]:bist_pass [4]:act_loaded [3]:irq | 0x00 | R/O | 主状态 |
| 0x11 | FSM_STATE | [7:0]:state_code | 0x00 | R/O | FSM 状态（0=IDLE, 2=MAC_RUN, 3=DONE, F=ERROR）|
| 0x12 | ERROR_CODE | [7:0]:err | 0x00 | R/O | 0x01=SA_TIMEOUT, 0x02=SPI_FRAMING, 0x04=ACC_OVF |
| 0x13 | STATUS_CLR | [3]:clr_err [2]:clr_bist [1]:clr_done | 0x00 | W1C | 写 1 清除对应 STATUS 位 |
| 0x14 | ADC_RAW_THERM | [2:0]:therm_code | 0x00 | R/O | SA thermometer 码（000/001/011/111）|
| 0x15 | SA_DEBUG | [7:6]:sel [5:0]:val | 0x00 | R/O | SA 内部节点调试 mux |
| 0x16 | DAC_CODE_DIRECT | [7:0]:dac_override | 0x00 | R/W | DAC 直接写入（SA 手动校准）|
| 0x17 | ANALOG_MUX_SEL | [3:0]:mux_ch | 0x00 | R/W | 0=IBIAS, 1=IREF0, 2=SA_in+, 3=SA_in- |
| 0x18 | READ_DATA | [7:0]:symbol | 0x00 | R/O | SA 解码后 2-bit 数据（0/1/2/3）|
| 0x19 | BIST_RESULT | [7]:done [6]:pass [5:0]:fail_row_hint | 0x00 | R/O | BIST 结果 |
| 0x1A | SCAN_CTRL | [1]:scan_mode [0]:scan_en | 0x00 | R/W | DFT 扫描链使能 |

## 0x20–0x23 MAC 累加器输出（26-bit signed，读回 sign-extend 为 int32）

| Addr | Name | Fields | Reset | Access | 说明 |
|------|------|--------|-------|--------|------|
| 0x20 | ACC_OUT_0 | [7:0]:acc[7:0] | 0x00 | R/O | Byte0 (LSB) |
| 0x21 | ACC_OUT_1 | [7:0]:acc[15:8] | 0x00 | R/O | Byte1 |
| 0x22 | ACC_OUT_2 | [7:0]:acc[23:16] | 0x00 | R/O | Byte2 |
| 0x23 | ACC_OUT_3 | [1:0]:acc[25:24] | 0x00 | R/O | Byte3（acc[25]=符号位）|

## 0x30–0x3F DFT/SCAN

| Addr | Name | 说明 |
|------|------|------|
| 0x30–0x37 | SCAN_REG | 扫描链数据寄存器（8 字节）|

## 0x40–0x43 act_regfile 间接访问

| Addr | Name | Fields | Reset | Access | 说明 |
|------|------|--------|-------|--------|------|
| 0x40 | ACT_ADDR_L | [7:0]:ptr[7:0] | 0x00 | R/W | act_regfile 间接地址低字节 |
| 0x41 | ACT_ADDR_H | [1:0]:ptr[9:8] | 0x00 | R/W | 高 2 位（支持 1024 行）|
| 0x42 | ACT_DATA | [7:0]:value | 0x00 | R/W | 读/写 act_regfile[ptr]，写后 ptr 自动+1 |
| 0x43 | ACT_CTRL | [0]:auto_inc | 0x01 | R/W | 写后自动递增（默认开）|

## 0x50–0x58 Group Scale / Dequant（W4→W8 反量化系数）

| Addr | Name | Fields | Reset | 说明 |
|------|------|--------|-------|------|
| 0x50 | SCALE_MODE | [1:0]:mode | 0x00 | 0=per-layer 1=per-8-group 2=bypass |
| 0x51 | SCALE_W_G0 | [7:0]:scale | 0x10 | Group 0（rows 0–127），per-layer 时唯一 |
| 0x52 | SCALE_W_G1 | [7:0]:scale | 0x10 | Group 1（rows 128–255）|
| 0x53 | SCALE_W_G2 | [7:0]:scale | 0x10 | Group 2（rows 256–383）|
| 0x54 | SCALE_W_G3 | [7:0]:scale | 0x10 | Group 3（rows 384–511）|
| 0x55 | SCALE_W_G4 | [7:0]:scale | 0x10 | Group 4（rows 512–639）|
| 0x56 | SCALE_W_G5 | [7:0]:scale | 0x10 | Group 5（rows 640–767）|
| 0x57 | SCALE_W_G6 | [7:0]:scale | 0x10 | Group 6（rows 768–895）|
| 0x58 | SCALE_W_G7 | [7:0]:scale | 0x10 | Group 7（rows 896–1023）|

---

## Bring-up SPI 操作序列

### Level 0（确认 SPI 通路）
chip_id = spi_read(0x00)       # 期望 0xA3  
version = spi_read(0x01)       # 期望 0x30  
spi_write(0x02, 0xA5)          # 写 SCRATCH  
scratch  = spi_read(0x02)      # 期望 0xA5 → Level 0 PASS

### Level 1（数字 BIST MAC bypass）
spi_write(0x50, 0x00)          # SCALE_MODE=per-layer  
spi_write(0x51, 0x10)          # SCALE_W_G0=16  
spi_write(0x04, 0x12)          # bypass_sa=1, act_load_mode=1  
# 批量写 act_regfile（1024 字节）  
spi_write(0x04, 0x94)          # bypass_sa=1, start=1  
while not (spi_read(0x10) & 0x80): pass  # 等 mac_done  
acc = read_acc_4byte()         # 读回 26-bit ACC

### Level 2（片内电流模拟器 → SA）
spi_write(0x0E, 0x40)          # int_dac_en=1, emul_code=0  
therm = spi_read(0x14)         # 期望 0x00（最小电流）  
spi_write(0x0E, 0x7F)          # emul_code=max  
therm = spi_read(0x14)         # 期望 0x07（最大电流）
