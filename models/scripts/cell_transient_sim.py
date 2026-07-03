"""
cell_transient_sim.py  — Phase B Step 3
Python-based 2T0C cell 瞬态仿真（等效 SPICE transient）
验收点：
  V1: Write "1" → VSN stable within ±5% of WBL  (VSN→WBL since WWL-VTH >> WBL)
  V2: 16 态分辨率验证:
       - IRBL 严格单调递增（16 态全部可分辨）
       - 读窗口 IRBL_15/IRBL_0 > 1e8
       - 亚阈区相邻比（state 0-2, VSN < VTH_R）> √10
  V3: Retention @OHAD corner (ΔV_SN < 0.1V at t=200s/1000s/1e4s)
"""
import numpy as np
import json, os, sys
try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
except ModuleNotFoundError:
    plt = None

# ─── 物理常数 ─────────────────────────────────────────────────────────────────
EPS0  = 8.854e-12
TOXE  = 10e-9
EPSOX = 22.0
COX   = EPSOX * EPS0 / TOXE   # 19.48e-3 F/m²
KT_Q  = 0.02585                # V @300K

# ─── Corner 参数表 ─────────────────────────────────────────────────────────────
CORNERS = {
    'nominal': dict(VTH0=0.63, IOFF0=1e-16, N_SS=1.22, MU0=6.0,  THETA=0.0, LAMBDA=0.003, ALPHA=0.5, RC=5e-9),
    'OHAD':    dict(VTH0=0.23, IOFF0=1e-19, N_SS=1.25, MU0=20.0, THETA=0.3, LAMBDA=0.005, ALPHA=1.8, RC=1.7e-9),
    'pilot':   dict(VTH0=0.63, IOFF0=1e-14, N_SS=1.60, MU0=6.0,  THETA=0.0, LAMBDA=0.003, ALPHA=0.5, RC=5e-9),
}

# ─── IGZO TFT 电流模型（Phase A 修正版）──────────────────────────────────────
def igzo_id(VGS, VDS, cp, W, L):
    """
    cp: corner dict.  返回 ID [A]。
    """
    Wref   = 1e-6
    n_sub  = cp['N_SS'] * np.log(10) * KT_Q
    Vgs_eff = VGS - cp['VTH0']
    VDS_pos = max(float(VDS), 0.0)

    Id_sub = (cp['IOFF0'] * W / Wref) * np.exp(
        np.clip(Vgs_eff / n_sub, -60, 1.0)) * (
        1.0 - np.exp(-VDS_pos / KT_Q))

    mu_eff  = (cp['MU0'] * 1e-4) / (1.0 + cp['THETA'] * max(Vgs_eff, 0.0))
    Beta    = mu_eff * COX * W / L
    Vgt     = max(Vgs_eff, 0.0)
    Vdsat   = Vgt / cp['ALPHA']
    Vds_eff = Vdsat * np.tanh(VDS_pos / (cp['ALPHA'] * Vdsat + 1e-12))
    Id_above = max(Beta * (Vgt * Vds_eff - 0.5 * Vds_eff**2) * (1.0 + cp['LAMBDA'] * VDS_pos), 0.0)

    return max(Id_sub, Id_above)


# ─── 2T0C Cell 瞬态仿真（简化 Runge-Kutta 积分）──────────────────────────────
def sim_cell_transient(
    corner='OHAD',
    Csn=5e-15,        # 存储节点电容 [F]
    W=500e-9, L=500e-9,
    # 操作序列: [(t_start, t_end, mode, V_WWL, V_WBL, V_RWL, V_RBL)]
    sequence=None,
    dt=1e-10,         # 时间步长 [s]（短时仿真用小步长）
):
    """
    返回 {'t': [...], 'VSN': [...], 'IRBL': [...]}
    """
    cp = CORNERS[corner]
    if sequence is None:
        # 默认: Write "1" (10ns) → Hold (1µs) → Read (10ns)
        sequence = [
            (0,      10e-9,  'write', 2.0, 0.9, 0.0, 1.0),
            (10e-9,  11e-6,  'hold',  -1.0, 0.0, 0.0, 0.0),
            (11e-6,  11.01e-6, 'read', -1.0, 0.0, 0.0, 1.0),
        ]

    t_end = max(s[1] for s in sequence)
    vsn = 0.0
    t_list, vsn_list, irbl_list = [], [], []

    t = 0.0
    step = dt
    t_save_interval = max(dt, t_end / 2000)   # 最多存 2000 点
    t_last_save = -t_save_interval

    while t <= t_end:
        # 找当前时刻的激励
        vwwl = -1.0; vwbl = 0.0; vrwl = 0.0; vrbl = 0.0
        for seg in sequence:
            t_s, t_e, mode, w_wwl, w_wbl, w_rwl, w_rbl = seg
            if t_s <= t <= t_e:
                vwwl = w_wwl; vwbl = w_wbl; vrwl = w_rwl; vrbl = w_rbl
                break

        # 写管: VGS_W = WWL - VSN, VDS_W = WBL - VSN
        vgs_w = vwwl - vsn
        vds_w = vwbl - vsn
        id_w = igzo_id(vgs_w, vds_w, cp, W, L)
        # 方向：从 WBL → SN（当 VDS_W > 0 时充电，反之放电）
        if vds_w < 0:
            id_w = -id_w   # 反向：SN 通过 M_W 放电到 WBL

        # 读管漏电: VGS_R = VSN - VTH, VDS_R = RBL - RWL = 1V
        vgs_r = vsn - 0.0   # source = RWL = 0V
        vds_r = vrbl - vrwl
        id_r = igzo_id(vgs_r, vds_r, cp, W, L)
        # 读管从 SN 取走电荷（RBL→RWL 电流实际是从 SN 抽走的，仅在 hold/read 期间）
        # Hold 时 WWL=-1V → M_W 截止，SN 仅通过 M_W 漏电（Ioff）和 M_R 读管漏电
        # 简化：hold 期间 VSN 变化主要由 M_W 亚阈漏电决定（Ioff），M_R 漏电已含在 igzo_id

        # VSN 微分方程: C × dVSN/dt = id_w - id_r(hold时) - Ioff*leak
        # 简化：在 hold 模式下，id_w 已包含 Ioff（反向流动从 SN→WBL）
        # id_r 在 hold 时 vrbl=0 → id_r ≈ Ioff 量级（可忽略）
        dvsn_dt = id_w / Csn   # 主要驱动

        vsn += dvsn_dt * step
        vsn = max(vsn, 0.0)   # 不能低于 0V
        if vwwl > 0:           # 写入期间：SN 不能超过 WBL（VDS_W=0 截止）
            vsn = min(vsn, max(vwbl, 0.0))

        # IRBL（读管电流）
        irbl = igzo_id(vsn, vds_r, cp, W, L) if vrbl > 0 else 0.0

        if t - t_last_save >= t_save_interval:
            t_list.append(t)
            vsn_list.append(vsn)
            irbl_list.append(irbl)
            t_last_save = t

        t += step

    return {'t': np.array(t_list), 'VSN': np.array(vsn_list), 'IRBL': np.array(irbl_list)}


# ─── V1 验收：Write "1" 和 Write "0" ──────────────────────────────────────────
def verify_v1(corner='nominal', Csn=5e-15, W=500e-9, L=500e-9):
    """验收 V1：写"1"(WBL=0.9V) 和写"0"(WBL=0V) 后 VSN 稳定性 ±5%。"""
    results = {}
    for label, wbl in [('write1', 0.9), ('write0', 0.0)]:
        seq = [(0, 20e-9, 'write', 2.0, wbl, 0.0, 1.0),
               (20e-9, 21e-9, 'hold', -1.0, 0.0, 0.0, 0.0)]
        out = sim_cell_transient(corner, Csn, W, L, seq, dt=5e-12)
        vsn_final = out['VSN'][-1]
        cp = CORNERS[corner]
        # VSN_target = min(WBL, WWL-VTH) = WBL, since WWL=2V >> VTH+WBL for all corners
        vsn_target = min(wbl, 2.0 - cp['VTH0'])
        err_pct = abs(vsn_final - vsn_target) / (vsn_target + 1e-3) * 100
        ok = bool(err_pct <= 5.0) if vsn_target > 0.01 else bool(vsn_final < 0.05)
        results[label] = {
            'WBL': wbl, 'VSN_target': float(vsn_target),
            'VSN_final': float(vsn_final), 'error_pct': float(err_pct), 'PASS': ok
        }
        print(f'  {label}: WBL={wbl}V, VSN_target={vsn_target:.3f}V, '
              f'VSN_final={vsn_final:.4f}V, err={err_pct:.1f}%, {"PASS" if ok else "FAIL"}')
    return results


# ─── V2 验收：16 态 IRBL 分辨率 ──────────────────────────────────────────────
def verify_v2(corner='OHAD', Csn=5e-15, W=500e-9, L=500e-9):
    """
    验收 V2：16 态 IRBL 分辨率。
    V2 PASS 准则：
      a) IRBL 严格单调递增（所有 16 态可分辨）
      b) 读窗口 IRBL_15/IRBL_0 > 1e8
      c) 亚阈区（state 0,1,2，VGS_R < VTH）相邻比 > √10

    写模型修正：VSN = min(WBL, WWL-VTH) = WBL（因 WWL=2V 远大于 VTH+WBL）
    读管：VGS_R = VSN, VDS_R = 1V
    """
    cp = CORNERS[corner]
    irbl_states = []
    vsn_states  = []
    for state in range(16):
        wbl = state * 0.1   # WBL = 0 ~ 1.5V
        # VSN = min(WBL, WWL-VTH); for WWL=2V this equals WBL
        vsn = min(wbl, 2.0 - cp['VTH0'])
        irbl = igzo_id(vsn, 1.0, cp, W, L)
        irbl_states.append(irbl)
        vsn_states.append(vsn)

    irbl_arr = np.array(irbl_states)

    # a) 单调性
    monotone = bool(np.all(irbl_arr[1:] > irbl_arr[:-1]))

    # b) 读窗口
    read_window = float(irbl_arr[-1] / (irbl_arr[0] + 1e-40))
    window_ok   = read_window > 1e8

    # c) 亚阈区（state 0→1, 1→2）相邻比
    sub_ratios = [irbl_arr[1] / (irbl_arr[0] + 1e-40),
                  irbl_arr[2] / (irbl_arr[1] + 1e-40)]
    sub_ratio_min = float(min(sub_ratios))
    sub_ok = sub_ratio_min >= np.sqrt(10)

    ok = monotone and window_ok and sub_ok
    print(f'  Monotone:        {monotone}')
    print(f'  Read window:     {read_window:.2e}  (target >1e8)  {"PASS" if window_ok else "FAIL"}')
    print(f'  Sub-Vth adj ratio: {sub_ratio_min:.2f}x  (target >sqrt(10)={np.sqrt(10):.2f})  '
          f'{"PASS" if sub_ok else "FAIL"}')
    print(f'  V2 overall:      {"PASS" if ok else "FAIL"}')

    # 相邻比全表（仅打印）
    all_ratios = [float(irbl_arr[i+1] / (irbl_arr[i] + 1e-40)) for i in range(15)]
    print(f'  Adjacent ratios: min={min(all_ratios):.2f}x  max={max(all_ratios):.2e}x')

    return {
        'VSN_states': [float(v) for v in vsn_states],
        'IRBL_states_A': [float(v) for v in irbl_arr],
        'monotone': monotone,
        'read_window': read_window,
        'sub_vth_min_ratio': sub_ratio_min,
        'all_adjacent_ratios': all_ratios,
        'PASS': bool(ok),
    }


# ─── V3 验收：Retention @OHAD ──────────────────────────────────────────────
def verify_v3(Csn=5e-15, W=500e-9, L=500e-9):
    """验收 V3：OHAD corner，ΔV_SN < 0.1V at t=200s/1000s/1e4s。"""
    cp = CORNERS['OHAD']
    # 初始 VSN（写入 state=9, WBL=0.9V）— 修正：VSN=min(WBL,WWL-VTH)=WBL=0.9V
    vsn0 = min(0.9, 2.0 - cp['VTH0'])   # = 0.9V for OHAD (WWL=2V, VTH=0.23)
    # 漂移公式（解析）: ΔV = Ioff × W / Csn × t
    I_leak = cp['IOFF0'] * (W * 1e6)   # A  (Ioff A/µm × W_µm)
    t_targets = [200.0, 1000.0, 1e4]
    results = []
    for t_hold in t_targets:
        dv = I_leak / Csn * t_hold
        vsn_t = vsn0 - dv
        ok = bool(abs(dv) < 0.1)
        results.append({
            't_hold_s': float(t_hold), 'VSN0': float(vsn0),
            'VSN_t': float(vsn_t), 'dV_SN': float(dv), 'PASS': ok
        })
        print(f'  t={t_hold:.0e}s: VSN {vsn0:.4f}->{vsn_t:.4f}V, '
              f'dV={dv:.4e}V, {"PASS" if ok else "FAIL"}')
    return results


# ─── 16-state IRBL LUT 生成 ──────────────────────────────────────────────────
def build_irbl_lut(corner='OHAD', W=500e-9, L=500e-9, VDS_read=1.0):
    """
    生成 16 态 IRBL-VSN 查找表（LUT）。
    写操作：WWL=2V, WBL=state×0.1V, M_W 源跟随器 → VSN = WBL - VTH_W
    读操作：RBL=1V, RWL=0V → IRBL = igzo_id(VSN, 1V)
    """
    cp = CORNERS[corner]
    states = list(range(16))
    wbl_vals  = [s * 0.1 for s in states]
    # VSN = min(WBL, WWL-VTH) = WBL for WWL=2V, VTH≤0.63V, WBL≤1.5V
    vsn_vals  = [min(w, 2.0 - cp['VTH0']) for w in wbl_vals]
    irbl_vals = [igzo_id(v, VDS_read, cp, W, L) for v in vsn_vals]

    lut = {
        'corner': corner,
        'W_m': W, 'L_m': L,
        'VDS_read_V': VDS_read,
        'states': states,
        'WBL_V': wbl_vals,
        'VSN_V': vsn_vals,
        'IRBL_A': irbl_vals,
        'IRBL_uA': [v * 1e6 for v in irbl_vals],
    }
    return lut


# ─── 绘图：write/hold/read 波形 ───────────────────────────────────────────────
def plot_transient(out_nom, out_ohad, out_path):
    if plt is None:
        return
    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    for i, (out, label) in enumerate([(out_nom, 'nominal'), (out_ohad, 'OHAD')]):
        t_us = out['t'] * 1e9  # ns
        axes[0][i].plot(t_us, out['VSN'], 'b-', lw=1.5)
        axes[0][i].set_xlabel('Time (ns)'); axes[0][i].set_ylabel('VSN (V)')
        axes[0][i].set_title(f'{label} corner — VSN transient')
        axes[0][i].grid(True, alpha=0.3)

        axes[1][i].semilogy(t_us, np.maximum(out['IRBL'], 1e-20) * 1e6, 'r-', lw=1.5)
        axes[1][i].set_xlabel('Time (ns)'); axes[1][i].set_ylabel('IRBL (µA)')
        axes[1][i].set_title(f'{label} corner — IRBL transient')
        axes[1][i].grid(True, which='both', alpha=0.3)

    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)
    print(f'  Plot: {out_path}')


def plot_lut(lut_nom, lut_ohad, out_path):
    if plt is None:
        return
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    for ax, lut, label in [(axes[0], lut_nom, 'nominal'), (axes[1], lut_ohad, 'OHAD')]:
        vsn = lut['VSN_V']
        irbl = [v * 1e6 for v in lut['IRBL_A']]
        ax.bar(range(16), irbl, color='steelblue', alpha=0.8)
        ax2 = ax.twinx()
        ax2.plot(range(16), vsn, 'r-o', ms=5, lw=1.5, label='VSN')
        ax.set_xlabel('State (0..15)')
        ax.set_ylabel('IRBL (µA)', color='steelblue')
        ax2.set_ylabel('VSN (V)', color='red')
        ax.set_title(f'16-state IRBL LUT ({label} corner)')
        ax.set_xticks(range(16))
        ax.grid(True, alpha=0.2)
        ax2.legend(loc='upper left', fontsize=9)
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)
    print(f'  Plot: {out_path}')


# ─── 主流程 ───────────────────────────────────────────────────────────────────
def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--outdir', default='.', help='Output directory')
    args = parser.parse_args()
    os.makedirs(args.outdir, exist_ok=True)

    print('=' * 60)
    print('Phase B: 2T0C Cell Transient Simulation')
    print('=' * 60)

    # ── V1: Write 1/0 验收 ──
    print('\n[V1] Write "1"/"0" -> VSN stability +/-5%')
    print('  Nominal corner:')
    v1_nom = verify_v1('nominal')
    print('  OHAD corner:')
    v1_ohad = verify_v1('OHAD')

    # ── V2: 16-state resolution ──
    print('\n[V2] 16-state IRBL resolution (OHAD corner)')
    v2 = verify_v2('OHAD')
    print('\n  State | WBL(V) | VSN(V) | IRBL(uA)')
    print('  ' + '-'*42)
    for s in range(16):
        print(f'  {s:2d}    | {v2["VSN_states"][s]*10:.1f}*0.1 | '
              f'{v2["VSN_states"][s]:.4f} | {v2["IRBL_states_A"][s]*1e6:.4e}')

    # ── V3: Retention @OHAD ──
    print('\n[V3] Retention verification (OHAD corner, Csn=5fF, state=9, WBL=0.9V)')
    v3 = verify_v3()

    # ── LUT 生成 ──
    print('\n[LUT] Build 16-state IRBL lookup table')
    lut_nom  = build_irbl_lut('nominal')
    lut_ohad = build_irbl_lut('OHAD')
    for lut, fn in [(lut_nom, 'irbl_lut_nominal.json'), (lut_ohad, 'irbl_lut_OHAD.json')]:
        with open(os.path.join(args.outdir, fn), 'w') as f:
            json.dump(lut, f, indent=2)
        print(f'  Saved: {fn}')

    # ── 瞬态波形（短时功能验证）──
    print('\n[Transient] Write/Hold/Read waveform (short sim)')
    seq_short = [
        (0,      20e-9,  'write', 2.0, 0.9, 0.0, 1.0),
        (20e-9,  2e-6,   'hold',  -1.0, 0.0, 0.0, 0.0),
        (2e-6,   2.02e-6,'read',  -1.0, 0.0, 0.0, 1.0),
    ]
    out_nom  = sim_cell_transient('nominal', sequence=seq_short, dt=1e-11)
    out_ohad = sim_cell_transient('OHAD',   sequence=seq_short, dt=1e-11)
    plot_transient(out_nom, out_ohad, os.path.join(args.outdir, 'cell_transient.png'))
    plot_lut(lut_nom, lut_ohad, os.path.join(args.outdir, 'irbl_lut.png'))

    # ── 保存综合结果（numpy 类型转换为 Python 原生类型）──
    def to_python(obj):
        if isinstance(obj, dict):
            return {k: to_python(v) for k, v in obj.items()}
        if isinstance(obj, list):
            return [to_python(v) for v in obj]
        if isinstance(obj, (np.bool_,)):
            return bool(obj)
        if isinstance(obj, (np.integer,)):
            return int(obj)
        if isinstance(obj, (np.floating,)):
            return float(obj)
        if isinstance(obj, np.ndarray):
            return obj.tolist()
        return obj

    summary = to_python({
        'V1_nominal': v1_nom, 'V1_OHAD': v1_ohad,
        'V2_16state': v2, 'V3_retention': v3,
        'lut_nominal': lut_nom, 'lut_OHAD': lut_ohad,
    })
    with open(os.path.join(args.outdir, 'cell_sim_results.json'), 'w') as f:
        json.dump(summary, f, indent=2)

    # ── 总验收 ──
    print('\n' + '=' * 60)
    print('ACCEPTANCE SUMMARY')
    print('=' * 60)
    v1_pass = all(r['PASS'] for r in v1_ohad.values())
    v2_pass = v2['PASS']
    v3_pass = all(r['PASS'] for r in v3)
    for name, ok in [('V1 Write stability', v1_pass), ('V2 16-state resolution', v2_pass),
                     ('V3 Retention @OHAD', v3_pass)]:
        print(f'  {name}: {"PASS" if ok else "FAIL"}')
    all_pass = v1_pass and v2_pass and v3_pass
    print(f'\n  OVERALL: {"ALL PASS" if all_pass else "SOME FAIL — check above"}')

if __name__ == '__main__':
    main()
