# BEOL Landing Matrix 规格 v1
**⚠️ 状态**: 初稿，需与微电子所许老师团队确认后冻结 | 2026-06-15

## 1. Landing Pad 参数（待确认）

| 参数 | 初始值 | 状态 |
|---|---|---|
| Landing pad pitch | 10 μm × 10 μm | ⚠️ 待 BEOL 团队确认 |
| Landing pad 开窗尺寸 | 8 μm × 8 μm（预计）| ⚠️ 待确认 |
| Landing pad 总数 | 12（BEOL_PAD01~12）| 初始估计 |
| 对准标记类型 | 十字形（±20μm 精度）| ⚠️ 待确认 |
| 金属层 | Metal4 或 Metal5 | ⚠️ 待确认（1P4M or 1P5M）|

## 2. BEOL Landing 功能分配

| Pad | 功能 | 信号 |
|---|---|---|
| BEOL_PAD01-04 | WBL（写位线）| WBL[0:3] |
| BEOL_PAD05-08 | RBL（读位线）| RBL[0:3] |
| BEOL_PAD09-10 | WWL（写字线）| WWL[0:1] |
| BEOL_PAD11-12 | RWL（读字线）| RWL[0:1] |

## 3. Daisy-chain 验证结构
- 4 个独立 daisy-chain 环路，用于 BEOL 工艺连通性验证
- 每条链：BEOL 互连 → Bond → CMOS M4 → 测试 pad

## 4. 后续行动
- [待办] 与许老师团队对齐 IGZO TFT 最小接触 pitch
- [待办] 确认 Monolithic 3D 工艺的层间对准精度要求
- [待办] 最终 landing spec 在 BEOL 确认后更新此文档
