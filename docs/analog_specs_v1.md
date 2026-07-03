# 模拟规格文档 v1
**来源**: 从 SMIC 0.18um PDK A_VT 分析导出 | 日期: 2026-06-15

---

## 1. SA / 比较器模块规格

| 参数 | 规格值 | 推导依据 |
|---|---|---|
| 架构 | CDS 积分式 + p33 电流镜（推荐架构 B） | 消除静态 offset，最优 SNR |
| 输入器件类型 | **p33 或 nmvt33（禁用 n33 作输入对）** | n33 A_VT=8mV·μm，失配最差；p33 A_VT=3.3mV·μm |
| 参考电流 DAC 器件 | p33, W≥20μm, L≥0.6μm | σ_ΔIref < 7 nA @1.089uA；σ_Vth=3.3e-9/√(12e-12)=0.95mV |
| IRBL 镜像器件 | p33, W≥20μm, L≥0.6μm | 同上 |
| 积分电容 C_int | ≥200 fF | CDS 残差 σ_ΔI_CDS < 1 nA |
| CDS 保持电容 C_hold | ≥500 fF | 时钟馈通 δVos < 0.1 mV |
| CDS 开关管 W/L | ≤ 2μm/0.18μm | 减小电荷注入 |
| 积分时间（4×4 阵列模式）| 20 ns | RC settling < 1%（τ=100ps@4×4） |
| 积分时间（256K 等效模式）| ≥100 ns | RC settling < 0.1%（τ=25ns@256K） |
| SA 输入总 3σ offset 预算 | < 280 nA（4×4 模式）| half_gap_min=835nA，留 3σ 余量 |
| 工作温度 | -40°C / 27°C / 85°C | SMIC model 支持 |
| 工作电压 | VDD33=3.3V ±10%，VDD18=1.8V ±10% | SMIC corner 覆盖 |

### SA Offset Budget（RSS 合并，4×4 模式）

| 来源 | 器件 | σ (nA) | 计算依据 |
|---|---|---|---|
| IGZO 阵列变化 | - | 122 | 行为 MC 反推（worst margin 6.85σ）|
| DAC 镜像失配 | p33 W=20μm L=0.6μm | 7 | σ_Vth=0.95mV，σ_ΔI/I=0.63%@1.089uA |
| IRBL 拷贝失配 | p33 W=20μm L=0.6μm | 2 | 同上@0.254uA（最低档）|
| CDS 残差（时钟馈通）| W=2μm/0.18μm | 1 | δVos=0.1mV，G_VtoI=10nA/mV |
| **合并 σ_total（4×4）** | | **122 nA** | √(122²+7²+2²+1²) |
| **裕量 margin（4×4）** | | **6.83σ** | half_gap(835nA)/122nA |

---

## 2. Reference DAC 规格

| 参数 | 规格值 |
|---|---|
| 输出电流 | 1.089 / 3.388 / 6.550 uA ±5%（trim 后）|
| DAC 类型 | 二进制加权 p33 电流镜阵列 |
| Trim 位数 | 4-bit，trim range ±30% |
| 单调性 | 所有 trim code 0~15 严格单调递增 |
| 温度系数 | < 500 ppm/°C（对应 Iref[0] 变化 < 54nA/°C）|
| 器件 | p33 W=20μm L=0.6μm（3 路 mirror）|
| σ_ΔIref/Iref | 0.63%（p33 W=20/L=0.6，σ_Vth=0.95mV）|
| PVT 覆盖 | TT/FF/SS/FNSP/SNFP × -40/27/85°C × 3.0/3.3/3.6V |

---

## 3. Driver / Level Shifter 规格

| 参数 | 规格值 | 来源 |
|---|---|---|
| LS 类型 | 1.8V → 3.3V，cross-coupled CMOS LS | 标准架构 |
| 无静态 crowbar 电流 | < 1 μA（所有 PVT 角落）| 器件可靠性 |
| t_rise（TT/标准负载）| < 5 ns | 时序要求 |
| t_rise（SS/-40°C）| < 10 ns | 最差角落 |
| WWL/RWL 建立时间 | < 10 ns（4×4 负载，Cload≤200fF）| IGZO 阵列时序 |
| WBL 建立时间 | < 5 ns（4×4 负载）| |
| 过压限制 | < 3.63V（110% VDD33）| 器件氧化层可靠性 |

---

## 4. 仿真矩阵要求（Phase E1 执行）

| 仿真类型 | Corner | 温度 | VDD33 | 运行次数 |
|---|---|---|---|---|
| SA DC 判决验证 | TT/SS/FF | 27°C | 3.3V | 4 档位 × 3 = 12 |
| SA Monte Carlo | TT/SS/FF | -40/27/85°C | 3.0/3.3/3.6V | 500 次/corner |
| SA PVT 全扫描 | TT/FF/SS/FNSP/SNFP | -40/27/85°C | 3.0/3.3/3.6V | 全矩阵 |
| DAC 单调性 | TT | 27°C | 3.3V | trim_code 0~15 |
| LS PVT | TT/FF/SS | -40/27/85°C | 1.62/1.8/1.98V | crowbar + t_rise |

