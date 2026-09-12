function out = func_roll_q2c(price_v, load_m, pv_m, day_list, L1, PV1, prm, K, R, cfg, verbose)
%FUNC_ROLL_Q2C  问题二第三轮：7 日滚动 SAA 两阶段随机 MILP（方案文档 §5~§15）
%
%   每天 d 的 0:00：
%     ① 用截止 d-1 的真实数据预测 d..d+R-1 的中心预测（同星期回溯；可叠加 B3 校正）；
%     ② 从最近 28 个有效残差日中随机无放回抽 K 天，构造 SAA 情景；
%     ③ 解两阶段 MILP：第一阶段定当天计划购电 G^plan_{d,t}（全情景共用），
%        第二阶段逐情景展开物理调度与未来 2..R 天的临时计划；
%     ④ **只执行当天的 G^plan**，用当天真实数据按建模手 C3 的优先级分流；
%     ⑤ 实际日末 SOC 传给次日。
%   一月（报告窗口之前）按已知数据处理，不预测、不进误差库（沿用 Q2b 口径）。
%
%   输入  cfg 结构体：gamma（B3 开关 0/1）、W、min_days、d_start、libW、seed、use_bin
%   输出  out  逐日矩阵、费用、预测层与情景层留档

T = prm.T;  dt = prm.dt;
[D, ~] = size(load_m);
if ~isfield(cfg, 'Kfc') || isempty(cfg.Kfc); cfg.Kfc = 4; end   % 同星期回溯周数（与情景数 K 不同）
if ~isfield(cfg, 'ideal') || isempty(cfg.ideal); cfg.ideal = false; end
if ~isfield(cfg, 'use_bin') || isempty(cfg.use_bin); cfg.use_bin = true; end
if ~isfield(cfg, 'd_max') || isempty(cfg.d_max); cfg.d_max = D; end
assert(cfg.d_max >= 1 && cfg.d_max <= D, 'cfg.d_max 越界');
hidx = floor((0:T-1)/6) + 1;
optL = optimoptions('linprog', 'Display', 'off');
% 收紧间隙容差：实测默认容差会提前收手（间隙 0.5~13.7 元），收紧后 gap 为 0 且更快
optM = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 600, ...
                    'RelativeGapTolerance', 1e-8, 'AbsoluteGapTolerance', 1e-8);

out = struct();
fld = {'buy_kw','em_m','chg_m','dis_m','curt_m','waste_m','Eend_m'};
for k = 1:numel(fld); out.(fld{k}) = zeros(D, T); end
out.E0_m = zeros(D,1);  out.cost = zeros(1,D);
out.cost_plan = zeros(1,D);  out.cost_em = zeros(1,D);
out.Z_model = zeros(D,1);  out.Keff = zeros(D,1);  out.degraded = false(D,1);
out.cut = zeros(D,1);      out.gap = zeros(D,1);   out.t_solve = zeros(D,1);
out.picked_m = nan(D, K);                     % 每日抽中的历史残差日索引（C1 可审计）
out.corr = struct('on', false(D,1), 'Lraw', zeros(D,T), 'PVraw', zeros(D,T), ...
                  'Lcor', zeros(D,T), 'PVcor', zeros(D,T), 'bL', zeros(D,24), 'bPV', zeros(D,24));

%% 断点续跑：长跑中途被打断时从上次断点继续（本轮曾因进程被杀白跑 5 分钟）
ckpt_file  = '';
ckpt_every = 20;                                              % 天
% 源码指纹：续跑前必须确认"产物与当前源码同版本"。本轮已发生过一次
% "L1 用旧版跑完 → 加断点 → 其余组用新版跑"的混版，光看参数签名抓不到。
sf = dir(fullfile(fileparts(mfilename('fullpath')), '*.m'));
src_fp = 0;
for i = 1:numel(sf)
    src_fp = mod(src_fp * 31 + sum(double(fileread(fullfile(sf(i).folder, sf(i).name)))), 2^40);
end
ckpt_sig   = struct('R',R, 'K',K, 'gamma',cfg.gamma, 'ideal',cfg.ideal, ...
                    'd_start',cfg.d_start, 'seed',cfg.seed, 'd_max',cfg.d_max, ...
                    'libW',cfg.libW, 'Kfc',cfg.Kfc, 'use_bin',cfg.use_bin, ...
                    'W',cfg.W, 'min_days',cfg.min_days, 'prm',prm, 'src_fp',src_fp);
d_from = 1;   E_from = prm.E_init;
if isfield(cfg,'ckpt') && ~isempty(cfg.ckpt)
    ckpt_file = cfg.ckpt;
    if exist(ckpt_file, 'file') > 0
        S = load(ckpt_file);
        if isfield(S, 'sig') && isequal(S.sig, ckpt_sig)
            out = S.out;   d_from = S.d_done + 1;   E_from = S.E_now;
            fprintf('    [断点续跑] 已完成 %d 天，自第 %d 天继续\n', S.d_done, d_from);
        else
            fprintf('    [断点作废] 签名不符（参数或源码已变），本组从头重跑\n');
        end
    end
end

%% B3 校正器所需的原始残差档案（校正量与点预测残差库均由此派生）
archRaw = func_resid_q2(load_m, pv_m, L1, PV1, cfg.Kfc, cfg.d_start);

%% 点预测残差库（SAA 用）：B3 开时为"原始残差 − 当日校正量"，否则等于原始残差
eL = archRaw.eL;  ePV = archRaw.ePV;
if cfg.gamma > 0
    for s = cfg.d_start:D
        [bL_s, bPV_s] = func_bias_q2(archRaw, day_list, s, cfg);
        eL(s,:)  = archRaw.eL(s,:)  - bL_s(hidx).';
        ePV(s,:) = archRaw.ePV(s,:) - bPV_s(hidx).';
    end
end
out.eL = eL;  out.ePV = ePV;  out.ok = archRaw.ok;

%% 滚动主循环
E_now = E_from;
t_all = tic;
for d = d_from:cfg.d_max
    dEnd = min(D, d + R - 1);
    nD   = dEnd - d + 1;

    % ① 中心预测（cfg.ideal = true 时为第一层理想基准：当天真实数据已知）
    didx = (d:dEnd).';
    if cfg.ideal
        Lc = load_m(didx, :);   PVc = pv_m(didx, :);
    else
        [Lh, PVh] = func_forecast_q2(load_m, pv_m, L1, PV1, cfg.Kfc, d);
        Lc = Lh(1:nD,:);   PVc = PVh(1:nD,:);
        known = didx < cfg.d_start;                   % 一月按已知
        Lc(known,:) = load_m(didx(known), :);   PVc(known,:) = pv_m(didx(known), :);
    end
    out.corr.Lraw(d,:) = Lc(1,:);   out.corr.PVraw(d,:) = PVc(1,:);

    % B3 校正：作用于整个视野的中心预测（情景误差库相对点预测定义，须同源）
    if cfg.gamma > 0 && d >= cfg.d_start
        [bL, bPV] = func_bias_q2(archRaw, day_list, d, cfg);
        Lc  = max(0, Lc  + bL(hidx).');               % R×T 与 1×T 隐式扩展
        PVc = max(0, PVc + bPV(hidx).');
        out.corr.on(d) = true;
        out.corr.bL(d,:) = bL.';  out.corr.bPV(d,:) = bPV.';
    end
    out.corr.Lcor(d,:) = Lc(1,:);   out.corr.PVcor(d,:) = PVc(1,:);

    % ② 情景（理想基准层不加扰动：情景 = 已知的真实数据）
    if cfg.ideal
        Lsc = reshape(Lc, nD, T, 1);   PVsc = reshape(PVc, nD, T, 1);
        sinfo = struct('Keff', 1, 'degraded', false, 'picked', []);
    else
        [Lsc, PVsc, sinfo] = func_scen_q2c(eL, ePV, archRaw.ok, d, K, nD, Lc, PVc, cfg.libW, cfg.seed);
    end
    out.Keff(d) = sinfo.Keff;   out.degraded(d) = sinfo.degraded;
    if ~isempty(sinfo.picked)
        out.picked_m(d, 1:numel(sinfo.picked)) = sinfo.picked;
    end

    % ③ 两阶段 MILP（LP 热启动）
    [f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q2c(price_v, Lsc, PVsc, E_now, prm, cfg.use_bin);
    t1 = tic;
    [x0, ~, ef0] = linprog(f, A, b, Aeq, beq, lb, ub, optL);
    assert(ef0 == 1, '第 %d 天 LP 松弛未收敛（exitflag=%d）', d, ef0);
    if cfg.use_bin
        [x, Z, ef, oM] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, x0, optM);
        assert(ef == 1 || ef == 2, '第 %d 天 MILP 未正常返回（exitflag=%d）', d, ef);
        gap = oM.absolutegap;
    else
        x = x0;  Z = f' * x0;  gap = 0;
    end
    out.t_solve(d) = toc(t1);   out.Z_model(d) = Z;   out.gap(d) = gap;

    % 最大约束违反量（供 §18 回传）
    vEq = max(abs(Aeq * x - beq));
    vIn = max(max(A * x - b), 0);
    out.viol(d) = max(vEq, vIn);

    % ④ 只执行当天计划
    GP = x(aux.iGP);
    o = func_exec_q2c(GP, load_m(d,:).', pv_m(d,:).', price_v, E_now, prm);

    out.buy_kw(d,:)  = GP.';
    out.em_m(d,:)    = o.H.';    out.chg_m(d,:) = o.C.';   out.dis_m(d,:) = o.D.';
    out.curt_m(d,:)  = o.V.';    out.waste_m(d,:) = o.W.';
    out.E0_m(d)      = E_now;    out.Eend_m(d,:) = o.E.';
    out.cost(d)      = o.cost;   out.cost_plan(d) = o.cost_plan;  out.cost_em(d) = o.cost_em;
    out.cut(d)       = d - 1;

    E_now = o.E(end);

    if ~isempty(ckpt_file) && mod(d, ckpt_every) == 0
        d_done = d;  sig = ckpt_sig;                     %#ok<NASGU>
        save(ckpt_file, 'out', 'd_done', 'E_now', 'sig');
    end

    if verbose > 0 && (mod(d, verbose) == 0 || d == D)
        fprintf(['    [%3d/%3d] 视界 %d 天 Keff=%d  累计费用 %12.2f 元  ' ...
                 '累计紧急 %9.1f kWh  单次 %5.2fs  已用 %.1f min\n'], ...
                d, D, nD, sinfo.Keff, sum(out.cost(1:d)), sum(out.em_m(1:d,:), 'all'), ...
                out.t_solve(d), toc(t_all)/60);
    end
end
out.R = R;  out.K = K;  out.cfg = cfg;  out.time = toc(t_all);

end
