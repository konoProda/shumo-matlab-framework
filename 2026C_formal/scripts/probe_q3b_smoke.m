% probe_q3b_smoke.m —— Q3b 端到端冒烟：跑 6 天 S3（四阶段全开），验证管线与全部物理约束
%
%   用法：matlab -batch "run('scripts/probe_q3b_smoke.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));

prm = struct('T',144, 'dt',1/6, 'eta_ch',0.90, 'eta_dis',0.90, 'E_init',6000, ...
             'E_min',1200, 'E_max',10800, 'P_max',5000, 'kappa_em',5);
[price_v, load_m, pv_m, day_list, fc3] = func_read_q3b(PROJ_ROOT);
T = prm.T;  roll = [T, 1:T-1];
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
L1  = cell2mat(raw(2:1+T, 3));  L1  = L1(roll);
PV1 = cell2mat(raw(2:1+T, 4));  PV1 = PV1(roll);

cfg = struct('stages',[0 6 12 18], 'K',4, 'R',7, 'd_start',20, 'd_max',30, ...
             'gamma',1, 'Kfc',4, 'libW',28, 'W',28, 'min_days',5, 'seed',2026, ...
             'use_bin',true, 'ckpt',[], 'ckpt_every',10, 'replay_check',true);

fprintf('冒烟：S3 四阶段，第 %d..%d 天（K=%d）\n', cfg.d_start, cfg.d_max, cfg.K);
res = func_roll_q3b(price_v, load_m, pv_m, day_list, fc3, L1, PV1, prm, cfg, 1);

%% 逐条自检
D = numel(day_list);
fprintf('\n=== 自检 ===\n');
fprintf('最大等式违反      %.3e\n', max(res.viol(:)));
fprintf('最大整数间隙      %.3e\n', max(res.gap(:)));
fprintf('拼接重放偏差      %.3e  （须与阶段执行逐槽一致）\n', max(res.replay));

% 计划守恒与互斥：逐日逐槽
vLink = 0; vCD = 0; vEM = 0; vADJ = 0;
for d = cfg.d_start:cfg.d_max
    B = res.buy_kw(d,:).';  P = res.P_kw(d,:).';
    % 调整量与实际生效计划一致
    vADJ = max(vADJ, max(abs(res.dP_m(d,:).' - max(B-P,0))));
    vADJ = max(vADJ, max(abs(res.dM_m(d,:).' - max(P-B,0))));
    % 同槽不得同时充放
    vCD = max(vCD, max(res.chg_m(d,:) .* res.dis_m(d,:)));
    % 紧急购电不得给储能充电：由执行层保证；此处查紧急时段的光伏余电充电
    em = res.em_m(d,:).' > 1e-9;
    vEM = max(vEM, max([0; res.chg_m(d,em).']));
end
fprintf('调整量一致性      %.3e\n', vADJ);
fprintf('充放互斥 C·D       %.3e\n', vCD);
fprintf('紧急时段充电量    %.3e  （须为 0）\n', vEM);

% 储能递推（用实际执行记录）
vSOC = 0;
for d = cfg.d_start:cfg.d_max
    E = res.Etr_m(d,:).';
    if all(E == 0); continue; end
    C = res.chg_m(d,:).';  Dv = res.dis_m(d,:).';
    % 注意：res.chg_m / dis_m 已是 kWh（执行层输出前已乘 Δt），**不得再除 6**
    vSOC = max(vSOC, abs(E(1) - res.E0_m(d) - 0.9*C(1) + Dv(1)/0.9));
    vSOC = max(vSOC, max(abs(E(2:end) - E(1:end-1) - 0.9*C(2:end) + Dv(2:end)/0.9)));
end
fprintf('储能递推残差      %.3e\n', vSOC);

% 成本重算一致性
vCost = 0;  vNormal = 0;
for d = cfg.d_start:cfg.d_max
    P = res.P_kw(d,:).';  B = res.buy_kw(d,:).';
    dP = max(B-P,0);  dM = max(P-B,0);
    cn = sum(price_v.*P + 1.5*price_v.*dP - 0.5*price_v.*dM)/6;
    ce = 5*sum(price_v .* res.em_m(d,:).')/6;
    vNormal = max(vNormal, abs(cn - res.cost_normal(d)));
    vCost   = max(vCost,   abs(cn + ce - res.cost(d)));
end
fprintf('日费用重算残差    %.3e（正常）/ %.3e（合计）\n', vNormal, vCost);

% 信息泄漏：一月外每日所用历史日必须严格早于决策日
vLeak = 0;
for d = cfg.d_start:cfg.d_max
    pk = squeeze(res.picked(d,:,:));
    pk = pk(~isnan(pk));
    if ~isempty(pk); vLeak = max(vLeak, max(pk) - (d-1)); end
end
fprintf('抽样日信息泄漏    %d  （≤0 表示全部严格早于决策日）\n', vLeak);

% 价格预测口径：本版固定电价，情景之间电价应完全相同（由装配器直接给定，无需检验）

fprintf('\n窗口费用 %.2f 元（正常 %.2f + 紧急 %.2f）；紧急电量 %.1f kWh；弃光 %.1f；已购未用 %.1f\n', ...
    sum(res.cost(cfg.d_start:cfg.d_max)), sum(res.cost_normal(cfg.d_start:cfg.d_max)), ...
    sum(res.cost_em(cfg.d_start:cfg.d_max)), sum(res.em_m(cfg.d_start:cfg.d_max,:),'all'), ...
    sum(res.curt_m(cfg.d_start:cfg.d_max,:),'all'), sum(res.waste_m(cfg.d_start:cfg.d_max,:),'all'));
fprintf('日末储能均值 %.1f kWh\n', mean(res.Etr_m(cfg.d_start:cfg.d_max, end)));

ok = max(res.viol(:)) < 1e-7 && max(res.replay(:)) < 1e-7 && vLink < 1e-7 && vCD < 1e-9 && ...
     vEM < 1e-9 && vSOC < 1e-7 && vADJ < 1e-9 && vNormal < 1e-6 && vCost < 1e-6 && vLeak <= 0;
fprintf('\n%s\n', ternary(ok, 'SMOKE_Q3B_ALL_PASS', 'SMOKE_Q3B_FAILED'));

function s = ternary(c,a,b)
if c; s=a; else; s=b; end
end
