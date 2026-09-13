function out = func_roll_q4(price_act, load_m, pv_m, day_list, fc3, L1, PV1, prc, prm, cfg, verbose)
%FUNC_ROLL_Q4  问题四：实时波动电价下的滚动调控（Q4-2 与 Q4-3 共用同一引擎）
%
%   在问题二/问题三的骨架上加入"电价预测 + 电价随机情景"：
%     cfg.stages = [0]           → Q4-2（只在 0:00 预测负荷/光伏/电价，对应 result4-2）
%     cfg.stages = [0 6 12 18]   → Q4-3（日内更新光伏预报并**用已实现价格更新价格预测**，对应 result4-3）
%
%   电价中心预测（裁决 C1/D-08）：
%     基础预测 = 同星期回溯；偏差校正 = 最近 W 日同小时残差均值（不按日型分组）
%     阶段 s 的**日内水平项**：L_{d,s} = mean_{t≤sl}[ π^act − π̂^{(d,0)} ]，
%     加到当天尚未执行时段；未来日不变。只用已实现价格 ⇒ 不泄漏未来。
%
%   三类误差（L / PV / π）取自**同一历史日**（§8 强制），情景由 func_scen_q4 生成。
%   **最终费用一律用附件4 真实价格重算**（§17/§27/§37.9/§37.10）：不得把中心预测或情景价格写进交付费用。
%
%   cfg.mode：'main' 正式（价格情景 SAA）｜'P0' 价格只取中心值（§38 消融）
%             ｜'ideal' 价格情景替换为真实价格（§36 完美价格信息基准，仅评价用）
%
%   输出  out 逐日矩阵、逐阶段诊断、价格预测与情景留档

T = prm.T;  dt = prm.dt;
D = size(load_m, 1);
dflt = struct('Kfc',4, 'R',7, 'use_bin',true, 'd_max',D, 'replay_check',true, ...
              'ckpt_every',10, 'W',28, 'min_days',5, 'libW',28, 'mode','main');
fn = fieldnames(dflt);
for i = 1:numel(fn)
    if ~isfield(cfg, fn{i}) || isempty(cfg.(fn{i})); cfg.(fn{i}) = dflt.(fn{i}); end
end
stages = cfg.stages(:).';   S = numel(stages);   horizon = cfg.R;
hidx = floor((0:T-1)/6) + 1;
assert(cfg.d_max >= 1 && cfg.d_max <= D, 'cfg.d_max 越界');

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
out.pic = nan(D,T,S);    out.pi_min = nan(D,S);       % 价格中心预测与情景最小值（保护性检查）
out.L_lvl = zeros(D,S);                               % 当日水平项
out.corr = struct('on', false(D,1), 'Lcor', zeros(D,T), 'PVc0', zeros(D,T), ...
                  'PIc0', zeros(D,T), 'bL', zeros(D,24), 'bPV', zeros(D,24));

%% 问题二残差档案（负荷/光伏）+ 附件3 分阶段残差库
arch2 = func_resid_q2(load_m, pv_m, L1, PV1, cfg.Kfc, cfg.d_start);
arch3 = func_resid_q3b(arch2, fc3, pv_m, cfg.d_start);

%% 断点
ckpt_file = '';
if isfield(cfg,'ckpt'); ckpt_file = cfg.ckpt; end
src_fp = 0;
if ~isempty(ckpt_file)
    sf = dir(fullfile(fileparts(mfilename('fullpath')), '*.m'));
    for i = 1:numel(sf)
        src_fp = mod(src_fp*31 + sum(double(fileread(fullfile(sf(i).folder, sf(i).name)))), 2^40);
    end
end
ckpt_sig = struct('stages',stages, 'K',cfg.K, 'R',cfg.R, 'gamma',cfg.gamma, 'mode',cfg.mode, ...
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
    dEnd = min(D, d + horizon - 1);   nFut = dEnd - d;

    % 负荷与问题二自建光伏的中心预测（B3 作用于整条视野）
    [Lh, PVq] = func_forecast_q2(load_m, pv_m, L1, PV1, cfg.Kfc, d);
    Lc = Lh(1:1+nFut, :);   PVq = PVq(1:1+nFut, :);
    didx = (d:dEnd).';
    if d < cfg.d_start; Lc = load_m(didx, :);  PVq = pv_m(didx, :); end
    if cfg.gamma > 0 && d >= cfg.d_start
        [bL, bPV] = func_bias_q2(arch2, day_list, d, cfg);
        Lc = max(0, Lc + bL(hidx).');   PVq = max(0, PVq + bPV(hidx).');
        out.corr.on(d) = true;  out.corr.bL(d,:) = bL.';  out.corr.bPV(d,:) = bPV.';
    end
    out.corr.Lcor(d,:) = Lc(1,:);

    % 电价中心预测（0:00 版本，整条视野）
    PI0 = prc.pi_hat0(d:dEnd, :);                     % (1+nFut)×T
    if d < cfg.d_start; PI0 = price_act(didx, :); end
    out.corr.PIc0(d,:) = PI0(1,:);

    B = zeros(T,1);   P = zeros(T,1);
    Ecur = E_now;     out.E0_m(d) = E_now;
    for si = 1:S
        sh = stages(si);   sl = sh * 6;   Tcur = T - sl;

        nLead = Tcur + nFut*T;
        lead = 1:nLead;
        [PVmix, ~] = mixed_pv(lead, fc3, d, si, PVq, nFut, T);
        if si == 1; out.corr.PVc0(d,:) = PVmix(1:T); end

        % ---- 电价中心预测：当日水平项只作用于当天尚未执行时段 ----
        PIC = PI0;                                    % (1+nFut)×T
        if sl > 0
            % 两侧都取列向量再作差：1×sl 与 sl×1 相减会静默广播成 sl×sl 矩阵
            Ls = mean(price_act(d, 1:sl).' - PI0(1, 1:sl).');
            if d < cfg.d_start; Ls = 0; end           % 一月按已知，无需水平项
            PIC(1, sl+1:T) = PI0(1, sl+1:T) + Ls;
            out.L_lvl(d,si) = Ls;
        end
        PIC_c = PIC(1, sl+1:T).';
        PIC_f = PIC(2:1+nFut, :).';
        out.pic(d, sl+1:T, si) = PIC_c;

        Lhat_c = Lc(1, sl+1:T).';   PVhat_c = PVmix(1:Tcur).';
        Lhat_f = Lc(2:1+nFut, :).'; PVhat_f = reshape(PVmix(Tcur+1:end), [T nFut]);
        PIC_fm = reshape(PIC(2:1+nFut, :).', [T nFut]);   % 需与 PVhat_f 同序（T×nFut）
        lead_f = reshape(lead(Tcur+1:end), [T nFut]);

        if d < cfg.d_start
            Ke = 1;
            Lsc_c = reshape(Lhat_c, Tcur, 1);    PVsc_c = reshape(PVhat_c, Tcur, 1);
            PIsc_c = reshape(PIC_c, Tcur, 1);
            Lsc_f = reshape(Lhat_f, T, nFut, 1); PVsc_f = reshape(PVhat_f, T, nFut, 1);
            PIsc_f = reshape(PIC_fm, T, nFut, 1);
            sinfo = struct('Keff',1, 'degraded',false, 'picked',[]);
        else
            [Lsc_c, PVsc_c, PIsc_c, Lsc_f, PVsc_f, PIsc_f, sinfo] = func_scen_q4(arch3, prc, ...
                d, sl, cfg.K, Lhat_c, PVhat_c, PIC_c, Lhat_f, PVhat_f, PIC_fm, lead_f, cfg);
            Ke = sinfo.Keff;
        end
        % ---- 价格情景的口径切换（消融 / 理想基准）----
        switch cfg.mode
            case 'P0'                                     % 只用中心价格预测（无价格风险建模）
                PIsc_c = repmat(PIC_c, 1, Ke);
                PIsc_f = repmat(PIC_fm, 1, 1, Ke);
            case 'ideal'                                  % 完美价格信息基准（仅评价用）
                PIsc_c = repmat(price_act(d, sl+1:T).', 1, Ke);
                pf = zeros(T, nFut, Ke);
                for j = 1:nFut
                    dd = min(d + j, D);
                    pf(:, j, :) = repmat(price_act(dd, :).', 1, 1, Ke);
                end
                PIsc_f = pf;
        end
        out.Keff(d,si) = Ke;  out.degraded(d,si) = sinfo.degraded;
        out.pi_min(d,si) = min([PIsc_c(:); PIsc_f(:)]);
        if ~isempty(sinfo.picked); out.picked(d,si,1:numel(sinfo.picked)) = sinfo.picked; end

        [f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q3b(PIsc_c, PIsc_f, ...
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
        if si == 1; P = Anew; end
        B(sl+1:T) = Anew;
        if aux.hasAdj
            out.dP_m(d, sl+1:T) = x(aux.iDP).';
            out.dM_m(d, sl+1:T) = x(aux.iDM).';
        end

        sl_next = T;  if si < S; sl_next = stages(si+1)*6; end
        seg = (sl+1):sl_next;
        % 实际执行层用**附件4 真实电价**计费（价格只影响经济权衡，不改变物理优先级）
        o = func_exec_q3b(B(seg), load_m(d,seg).', pv_m(d,seg).', price_act(d,seg).', Ecur, prm);
        out.em_m(d,seg)   = o.H.';   out.chg_m(d,seg) = o.C.';   out.dis_m(d,seg) = o.D.';
        out.curt_m(d,seg) = o.V.';   out.waste_m(d,seg) = o.W.';
        out.Etr_m(d,seg)  = o.E.';
        Ecur = o.E(end);
    end

    % 结算：一律用真实电价、相对 0:00 原计划、只结算最终生效版本
    pa = price_act(d, :).';
    dP = max(B - P, 0);   dM = max(P - B, 0);
    out.buy_kw(d,:) = B.';   out.P_kw(d,:) = P.';
    out.cost_normal(d) = sum(pa.*P + 1.5*pa.*dP - 0.5*pa.*dM) * dt;
    % 注意：em_m 已是 kWh（执行层输出前已乘 dt），此处**不得再乘 dt**
    out.cost_em(d)     = prm.kappa_em * sum(pa .* out.em_m(d,:).');
    out.cost(d)        = out.cost_normal(d) + out.cost_em(d);
    E_now = Ecur;

    if cfg.replay_check
        orp = func_exec_q3b(B, load_m(d,:).', pv_m(d,:).', pa, out.E0_m(d), prm);
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
        fprintf(['    [%3d/%3d] %s 阶段 %s Keff=%d  累计费用 %12.2f 元  ' ...
                 '累计紧急 %9.1f kWh  价格情景最小 %+.3f  本日 %.2fs  已用 %.1f min\n'], ...
            d, D, cfg.mode, mat2str(stages), max(out.Keff(d,:)), sum(out.cost(1:d)), ...
            sum(out.em_m(1:d,:), 'all'), min(out.pi_min(d,~isnan(out.pi_min(d,:)))), ...
            sum(out.t_solve(d,:)), toc(t_all)/60);
    end
end
out.stages = stages;  out.K = cfg.K;  out.R = cfg.R;  out.mode = cfg.mode;  out.cfg = cfg;
out.time = toc(t_all);   out.rep_idx = (find(day_list == datetime(2025,2,1)):D).';

end

% ================================================================= 局部函数
function [pv, is3] = mixed_pv(lead, fc3, d, si, PVq, nFut, T)
%MIXED_PV  近端（lead ≤ 24h）用附件3、远端用问题二自建光伏中心预测
nLead = numel(lead);
pv = zeros(1, nLead);   is3 = false(1, nLead);
f24 = squeeze(fc3(d, si, :)).';
p10 = func_interp_q3b(f24, T);
near = lead <= T;
pv(near) = p10(lead(near));
is3(near) = true;
faridx = find(~near);
if ~any(faridx); return; end
L      = lead(faridx);
dayrel = floor((L - 1) / T) + 1;
slot   = mod(L - 1, T) + 1;
row    = min(1 + dayrel, 1 + nFut);
pv(faridx) = PVq(sub2ind(size(PVq), row(:).', slot(:).'));
end
