function out = func_roll_q3b(price_v, load_m, pv_m, day_list, fc3, L1, PV1, prm, cfg, verbose)
%FUNC_ROLL_Q3B  问题三第二版：日内多阶段滚动 SAA-MILP（四时点预报更新 + 购电计划再调整）
%
%   对每个日期 d，按求解 → 执行 → 更新真实状态 → 再求解推进：
%       阶段 0（0:00）求解全天计划 P → 执行 0:00–6:00 → 得到真实储电量
%       阶段 6 / 12 / 18 同理，各阶段只调整尚未执行时段的购电计划 A^s
%   最终生效计划 B 按时间片拼接 P→A^6→A^12→A^18；调整费统一相对 P 结算一次。
%
%   中心预测：负荷沿用问题二预测器（同星期回溯 + B3，日内不重训，）；
%             光伏近端 24 h 用附件3 最新预报（不做确定性校正，）、
%             远端用问题二自建预测（保留 B3）。
%   情景：负荷与光伏误差取自同一历史日（func_scen_q3b，）。
%   一月按已知数据处理、情景退化 K=1；d_start 之前不产生任何残差。
%
%   输入  fc3  D×4×24 附件3；arch3 由本函数内部建（需 fc3 与 pv_m）
%         cfg 结构体：stages / K / R / d_start / d_max / gamma / Kfc / libW / seed /
%                     W / min_days / use_bin / ckpt / ckpt_every / replay_check
%   输出  out 逐日矩阵、逐阶段诊断与预测层留档

T = prm.T;  dt = prm.dt;
D = size(load_m, 1);
dflt = struct('Kfc',4, 'R',7, 'use_bin',true, 'd_max',D, 'replay_check',true, ...
              'ckpt_every',10, 'W',28, 'min_days',5, 'libW',28);
fn = fieldnames(dflt);
for i = 1:numel(fn)
    if ~isfield(cfg, fn{i}) || isempty(cfg.(fn{i})); cfg.(fn{i}) = dflt.(fn{i}); end
end
stages = cfg.stages(:).';
S = numel(stages);
horizon = cfg.R;
assert(cfg.d_max >= 1 && cfg.d_max <= D, 'cfg.d_max 越界');
assert(all(mod(stages, 6) == 0) && stages(1) == 0, '阶段集合非法（须以 0 起、且为 6 的倍数）');
hidx = floor((0:T-1)/6) + 1;

optL = optimoptions('linprog', 'Display', 'off', 'Algorithm', 'dual-simplex');
optM = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 600, ...
                    'RelativeGapTolerance', 1e-8, 'AbsoluteGapTolerance', 1e-8);

out = struct();
fld = {'buy_kw','P_kw','em_m','chg_m','dis_m','curt_m','waste_m','Etr_m','dP_m','dM_m'};
for k = 1:numel(fld); out.(fld{k}) = zeros(D, T); end
out.E0_m = zeros(D,1);
out.cost = zeros(1,D);  out.cost_normal = zeros(1,D);  out.cost_em = zeros(1,D);
out.Z_model = nan(D,S);  out.gap = nan(D,S);  out.t_solve = zeros(D,S);
out.Keff = nan(D,S);     out.degraded = false(D,S);   out.picked = nan(D,S,cfg.K);
out.viol = zeros(D,S);   out.replay = zeros(D,S);
out.corr = struct('on', false(D,1), 'Lraw', zeros(D,T), 'Lcor', zeros(D,T), ...
                  'PVc0', zeros(D,T), 'PVsrc0', false(D,T), ...
                  'PVq0', zeros(D,T), 'bL', zeros(D,24), 'bPV', zeros(D,24));

%% 预测层档案（问题二口径）+ 附件3 分阶段残差库
arch2 = func_resid_q2(load_m, pv_m, L1, PV1, cfg.Kfc, cfg.d_start);
arch3 = func_resid_q3b(arch2, fc3, pv_m, cfg.d_start);

%% 断点续跑：签名含源码指纹，避免"产物与源码不同版本"的混版
ckpt_file = '';
if isfield(cfg,'ckpt'); ckpt_file = cfg.ckpt; end
src_fp = 0;
if ~isempty(ckpt_file)
    sf = dir(fullfile(fileparts(mfilename('fullpath')), '*.m'));
    for i = 1:numel(sf)
        src_fp = mod(src_fp*31 + sum(double(fileread(fullfile(sf(i).folder, sf(i).name)))), 2^40);
    end
end
ckpt_sig = struct('stages',stages, 'K',cfg.K, 'R',cfg.R, 'gamma',cfg.gamma, ...
                  'd_start',cfg.d_start, 'seed',cfg.seed, 'd_max',cfg.d_max, ...
                  'libW',cfg.libW, 'Kfc',cfg.Kfc, 'use_bin',cfg.use_bin, ...
                  'W',cfg.W, 'min_days',cfg.min_days, 'prm',prm, 'src_fp',src_fp);
d_from = 1;   E_from = prm.E_init;
if ~isempty(ckpt_file) && exist(ckpt_file, 'file') > 0
    Ss = load(ckpt_file);
    if isfield(Ss,'sig') && isequal(Ss.sig, ckpt_sig)
        out = Ss.out;  d_from = Ss.d_done + 1;  E_from = Ss.E_now_ck;
        fprintf('    [断点续跑] 已完成 %d 天，自第 %d 天继续\n', Ss.d_done, d_from);
    else
        fprintf('    [断点作废] 签名不符（参数或源码已变），本组从头重跑\n');
    end
end

%% 主循环
E_now = E_from;
t_all = tic;
for d = d_from:cfg.d_max
    dEnd = min(D, d + horizon - 1);
    nFut = dEnd - d;

    % ---------- ① 中心预测：负荷 + 问题二自建光伏（B3 作用于整条视野，日内不重算）----------
    [Lh, PVq] = func_forecast_q2(load_m, pv_m, L1, PV1, cfg.Kfc, d);
    Lc = Lh(1:1+nFut, :);   PVq = PVq(1:1+nFut, :);
    didx = (d:dEnd).';
    if d < cfg.d_start                                   % 一月按已知
        Lc = load_m(didx, :);   PVq = pv_m(didx, :);
    end
    out.corr.Lraw(d,:) = Lc(1,:);   out.corr.PVq0(d,:) = PVq(1,:);
    if cfg.gamma > 0 && d >= cfg.d_start
        [bL, bPV] = func_bias_q2(arch2, day_list, d, cfg);
        Lc  = max(0, Lc  + bL(hidx).');
        PVq = max(0, PVq + bPV(hidx).');
        out.corr.on(d) = true;  out.corr.bL(d,:) = bL.';  out.corr.bPV(d,:) = bPV.';
    end
    out.corr.Lcor(d,:) = Lc(1,:);

    % ---------- ② 逐阶段：求解 → 执行 → 更新 → 再求解 ----------
    B = zeros(T,1);   P = zeros(T,1);
    Ecur = E_now;     out.E0_m(d) = E_now;
    for si = 1:S
        sh = stages(si);   sl = sh * 6;   Tcur = T - sl;

        % --- 混合光伏中心预测：近端附件3、远端问题二自建 ---
        nLead = Tcur + nFut*T;
        lead = 1:nLead;
        [PVmix, is3] = mixed_pv(lead, fc3, d, si, PVq, nFut, T);
        if si == 1                                       % 留档 0:00 视角的混合预测
            out.corr.PVc0(d,:) = PVmix(1:T);
            out.corr.PVsrc0(d,:) = is3(1:T);
        end

        % --- 情景（固定电价版：全情景电价相同）---
        Lhat_c = Lc(1, sl+1:T).';      PVhat_c = PVmix(1:Tcur).';
        Lhat_f = Lc(2:1+nFut, :).';    PVhat_f = reshape(PVmix(Tcur+1:end), [T nFut]);
        lead_f = reshape(lead(Tcur+1:end), [T nFut]);
        if d < cfg.d_start
            Lsc_c = reshape(Lhat_c, Tcur, 1);    PVsc_c = reshape(PVhat_c, Tcur, 1);
            Lsc_f = reshape(Lhat_f, T, nFut, 1); PVsc_f = reshape(PVhat_f, T, nFut, 1);
            sinfo = struct('Keff',1, 'degraded',false, 'picked',[]);
        else
            [Lsc_c, PVsc_c, Lsc_f, PVsc_f, sinfo] = func_scen_q3b(arch3, d, sl, cfg.K, ...
                Lhat_c, PVhat_c, Lhat_f, PVhat_f, lead_f, cfg);
        end
        out.Keff(d,si) = sinfo.Keff;  out.degraded(d,si) = sinfo.degraded;
        if ~isempty(sinfo.picked); out.picked(d,si,1:numel(sinfo.picked)) = sinfo.picked; end

        % --- 装配与求解 ---
        Pcur = repmat(price_v(sl+1:T), 1, sinfo.Keff);
        Pfut = repmat(price_v, 1, nFut, sinfo.Keff);
        [f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q3b(Pcur, Pfut, ...
            Lsc_c, PVsc_c, Lsc_f, PVsc_f, P, sl, Ecur, prm, cfg.use_bin);
        t1 = tic;
        [x0, ~, ef0] = linprog(f, A, b, Aeq, beq, lb, ub, optL);
        assert(ef0 == 1, '第 %d 天阶段 %d 的 LP 松弛未收敛（exitflag=%d）', d, sh, ef0);
        if cfg.use_bin
            [x, Z, ef, oM] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, x0, optM);
            assert(ef == 1 || ef == 2, '第 %d 天阶段 %d 的 MILP 未正常返回（exitflag=%d）', d, sh, ef);
            gap = oM.absolutegap;
        else
            x = x0;  Z = f'*x0;  gap = 0;
        end
        out.t_solve(d,si) = toc(t1);  out.Z_model(d,si) = Z;  out.gap(d,si) = gap;
        out.viol(d,si) = max(abs(Aeq*x - beq));

        Anew = x(aux.iA);
        if si == 1; P = Anew; end                        % 当天 0:00 原始计划（锁定）
        B(sl+1:T) = Anew;
        if aux.hasAdj
            out.dP_m(d, sl+1:T) = x(aux.iDP).';
            out.dM_m(d, sl+1:T) = x(aux.iDM).';
        end

        % --- 只执行到下一次预报更新 ---
        sl_next = T;  if si < S; sl_next = stages(si+1)*6; end
        seg = (sl+1):sl_next;
        o = func_exec_q3b(B(seg), load_m(d,seg).', pv_m(d,seg).', price_v(seg), Ecur, prm);
        out.em_m(d,seg)   = o.H.';   out.chg_m(d,seg) = o.C.';   out.dis_m(d,seg) = o.D.';
        out.curt_m(d,seg) = o.V.';   out.waste_m(d,seg) = o.W.';
        out.Etr_m(d,seg)  = o.E.';
        Ecur = o.E(end);
    end

    % ---------- ③ 结算：一律相对 0:00 原计划，只结算最终生效版本 ----------
    dP = max(B - P, 0);   dM = max(P - B, 0);
    cost_norm = sum(price_v .* P + 1.5*price_v.*dP - 0.5*price_v.*dM) * dt;
    % 单位守卫：紧急购电量必须是 kWh 量级（执行层已乘 dt），若被误当功率存将在此暴露
    assert(max(out.em_m(d,:)) < 1e4, '紧急购电量量级异常（疑似单位错）');
% 注意：em_m 已是 kWh（执行层输出前已乘 dt），此处不得再乘 dt
    cost_em   = prm.kappa_em * sum(price_v .* out.em_m(d,:).');
    out.buy_kw(d,:) = B.';   out.P_kw(d,:) = P.';
    out.cost_normal(d) = cost_norm;  out.cost_em(d) = cost_em;
    out.cost(d) = cost_norm + cost_em;
    E_now = Ecur;

    % ---------- ④ 拼接后一次性重放：只作复核，须与阶段执行逐槽一致 ----------
    if cfg.replay_check
        orp = func_exec_q3b(B, load_m(d,:).', pv_m(d,:).', price_v, out.E0_m(d), prm);
        out.replay(d) = max([max(abs(orp.E.' - out.Etr_m(d,:))), ...
                             max(abs(orp.H.' - out.em_m(d,:))), ...
                             max(abs(orp.C.' - out.chg_m(d,:))), ...
                             max(abs(orp.D.' - out.dis_m(d,:)))]);
    end

    if ~isempty(ckpt_file) && mod(d, cfg.ckpt_every) == 0
        d_done = d;  sig = ckpt_sig;   E_now_ck = E_now;      %#ok<NASGU>
        save(ckpt_file, 'out', 'd_done', 'E_now_ck', 'sig');
    end

    if verbose > 0 && (mod(d, verbose) == 0 || d == cfg.d_max)
        fprintf(['    [%3d/%3d] 阶段 %s  Keff=%d  累计费用 %12.2f 元  ' ...
                 '累计紧急 %9.1f kWh  本日 %.2fs  已用 %.1f min\n'], ...
            d, D, mat2str(stages), max(out.Keff(d,:)), sum(out.cost(1:d)), ...
            sum(out.em_m(1:d,:), 'all'), sum(out.t_solve(d,:)), toc(t_all)/60);
    end
end
out.stages = stages;  out.K = cfg.K;  out.R = cfg.R;  out.cfg = cfg;
out.time = toc(t_all);   out.rep_idx = (find(day_list == datetime(2025,2,1)):D).';

end

% ================================================================= 局部函数
function [pv, is3] = mixed_pv(lead, fc3, d, si, PVq, nFut, T)
%MIXED_PV  按提前量拼出光伏中心预测：近端（lead ≤ 24h）用附件3，远端用问题二自建
%   pv 1×nLead；is3 同长度逻辑，true = 该槽取自附件3（诊断留档）
nLead = numel(lead);
pv = zeros(1, nLead);   is3 = false(1, nLead);
f24 = squeeze(fc3(d, si, :)).';
p10 = func_interp_q3b(f24, T);                   % 该次发布的 24 h 内插值
near = lead <= T;
pv(near) = p10(lead(near));
is3(near) = true;

faridx = find(~near);
if ~any(faridx); return; end
L      = lead(faridx);
dayrel = floor((L - 1) / T) + 1;                 % 1 = 次日
slot   = mod(L - 1, T) + 1;
row    = min(1 + dayrel, 1 + nFut);              % 视野外按末日平延（年末截断用）
pv(faridx) = PVq(sub2ind(size(PVq), row(:).', slot(:).'));
end
