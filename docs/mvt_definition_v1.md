# 最小可行流片（MVT）功能清单 v1 | 2026-06-15

## 必保功能（Must-Have，不可裁剪）

| 功能块 | 理由 |
|---|---|
| SPI 接口 + CHIP_ID/SCRATCH CSR | 回片第一步，确认数字通信链路 |
| 全部 Bring-up CSR（0x00~0x1F）| FSM_STATE/ERROR_CODE 等 debug 必需 |
| 数字 MAC bypass 模式（BIST_MAC）| bypass_sa=1，验证数字逻辑 |
| 片内电流模拟器（Current Emulator）| 不用 IGZO 也能测 SA |
| 2-bit SA 测试结构 | 核心电路，必须有 MC 数据才能投片 |
| External injection pads（IRBL_EXT）| 外部 SMU 直接注入测 SA |
| BEOL landing matrix + daisy-chain | 后续 IGZO 堆叠接口 |
| Scan chain（DFT）| 投片后数字调试手段 |

## 可裁剪（Nice-to-Have）

| 功能块 | 裁剪方案 | 影响 |
|---|---|---|
| act_regfile 1024 行 | 裁减为 256×8bit（节省约 75%面积）| MAC 只测 256 行 |
| per-8-group scale | 初次只用 SCALE_MODE=0（per-layer）| 精度略低 |
| 1024 行全 MAC | 先测 4/16/64/256 递增 | 快速定位问题 |

## 不建议裁剪

CHIP_ID / SCRATCH / BIST / scan chain / debug mux / analog_mux_sel / error_code

## MVT 点亮时间线

| 里程碑 | 时间 | 判据 |
|---|---|---|
| Level 0 通过 | 回片后 Day 1 | SPI 通路确认 |
| Level 1 通过 | Day 1-2 | MAC bit-exact |
| Level 2 通过 | Day 2-3 | SA thermometer 码正确 |
| Level 3 通过 | Day 3-5 | 完整链路 ACC==golden |
| Level 4a | BEOL 后 Day 1-2 | BER < 1e-3 |
