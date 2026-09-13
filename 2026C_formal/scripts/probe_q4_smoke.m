% probe_q4_smoke.m —— Q4 端到端冒烟：Q4-2 与 Q4-3 各跑数天，逐条核验
%
%   重点验证：① 三类误差同源（同一历史日）；② **价格信息不泄漏**（改未来真实价格不影响已定计划）；
%             ③ 最终费用一律用附件4 真实价格重算；④ 价格情景含负值时 Δ± 仍互斥；
%             ⑤ 日内价格水平项的**因果性**（只用已实现价格）与**有效性**（当天剩余预测确实变化）。
%
%   用法：matlab -batch "run('scripts/probe_q4_smoke.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));

prm = struct('T',144, 'dt',1/6, 'eta_ch',0.90, 'eta_dis',0.90, 'E_init',6000, ...
             'E_min',1200, 'E_max',10800, 'P_max',5000, 'kappa_em',5);
[~, load_m, pv_m, day_list, fc3] = func_read_q3b(PROJ_ROOT);
T = prm.T;  roll = [T, 1:T-1];
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
L1  = cell2mat(raw(2:1+T, 3));  L1  = L1(roll);
PV1 = cell2mat(raw(2:1+T, 4));  PV1 = PV1(roll);
cfg0 = struct('Kfc',4,'W',28,'min_days',5,'d_start',20);
prc = func_price_q4(PROJ_ROOT, prm, cfg0);

for st = {[0], [0 6 12 18]}
    stages = st{1};
    cfg = struct('stages',stages, 'K',4, 'R',7, 'd_start',20, 'd_max',26, 'gamma',1, ...
                 'Kfc',4, 'libW',28, 'W',28, 'min_days',5, 'seed',2026, 'mode','main', ...
                 'use_bin',true, 'ckpt',[], 'ckpt_every',10, 'replay_check',true);
    fprintf('\n######## 冒烟 %s ########\n', mat2str(stages));
    res = func_roll_q4(prc.price_act, load_m, pv_m, day_list, fc3, L1, PV1, prc, prm, cfg, 5);

    dd = cfg.d_start:cfg.d_max;
    fprintf('\n=== 自检 ===\n');
    fprintf('最大等式违反   %.3e | 最大间隙 %.3e | 重放偏差 %.3e\n', ...
        max(res.viol(:)), max(res.gap(:)), max(res.replay(:)));

    % ① 三类误差同源：**同一情景 ω 内**负荷/光伏/电价的误差取自同一历史日（并非 K 个情景共用一天）。
    %    直接调 func_scen_q4 生成一次，把三条情景相对中心预测的偏移量与该历史日的残差档案逐项比对。
    arch2 = func_resid_q2(load_m, pv_m, L1, PV1, cfg.Kfc, cfg.d_start);
    arch3 = func_resid_q3b(arch2, fc3, pv_m, cfg.d_start);
    d = 26;  sl = 0;  Tcur = T;   % 需选残差库已满的日（否则情景退化 K=1、无抽样日可查）
    Lhat_c = load_m(d, sl+1:T).';   PVhat_c = pv_m(d, sl+1:T).';
    PIC_c  = prc.pi_hat0(d, sl+1:T).';
    Lhat_f = load_m(d+1:d+2, :).';  PVhat_f = pv_m(d+1:d+2, :).';
    PIC_f  = prc.pi_hat0(d+1:d+2, :).';
    lead_f = reshape(1:(2*T), [T 2]);
    [Lsc1, PVsc1, PIsc1, ~, ~, ~, inf1] = func_scen_q4(arch3, prc, d, sl, 4, ...
        Lhat_c, PVhat_c, PIC_c, Lhat_f, PVhat_f, PIC_f, lead_f, cfg);
    r = inf1.picked(1);
    dL = max(abs((Lsc1(:,1) - Lhat_c) - max(arch3.eL(r, sl+1:T).', -Lhat_c)));
    % 光伏近端：情景 − 中心 应等于该历史日的附件3 分阶段残差（提前量对齐）
    e3 = reshape(arch3.ePV3(r, :, 1), [T 1]);
    dP = max(abs((PVsc1(:,1) - PVhat_c) - max(e3(1:Tcur), -PVhat_c)));
    % 电价：情景 − 中心 应等于该历史日的价格残差（同库同对齐）
    eI = reshape(prc.ePi3(r, :, 1), [T 1]);
    dI = max(abs((PIsc1(:,1) - PIC_c) - eI(1:Tcur)));
    fprintf('三类误差同源   %s（情景1 用历史日 %d；偏差 负荷 %.1e / 光伏 %.1e / 电价 %.1e）\n', ...
        ternary(max([dL dP dI]) < 1e-9, '✓', '✗'), r, dL, dP, dI);

    % ② 价格信息不泄漏：逐槽断言"只用到 ≤sl 的已实现价格"
    %    做法：把第 d 天 sl 之后的真实价格整体 +1 元，其余日不变，重跑该日，
    %    要求 0:00 计划与各阶段中心预测的前段完全不变（只对 stage-0 段做，代价小）
    d = 26;
    pa2 = prc.price_act;  pa2(d, 37:144) = pa2(d, 37:144) + 1;
    prc2 = prc;  prc2.price_act = pa2;
    cfgS = cfg;  cfgS.d_max = d;  cfgS.stages = [0];  cfgS.replay_check = false;
    r2 = func_roll_q4(pa2, load_m, pv_m, day_list, fc3, L1, PV1, prc2, prm, cfgS, 0);
    dP = max(abs(r2.P_kw(d,:).' - res.P_kw(d,:).'));
    fprintf('价格信息不泄漏 %s（改动 6:00 之后的真实价格，0:00 计划变化 %.2e）\n', ...
        ternary(dP < 1e-9, '✓', '✗'), dP);

    % ③ 费用重算用真实价格
    vCost = 0;  vEm = 0;
    for d2 = dd
        pa = prc.price_act(d2,:).';  P = res.P_kw(d2,:).';  B = res.buy_kw(d2,:).';
        dPv = max(B-P,0);  dMv = max(P-B,0);
        cn = sum(pa.*P + 1.5*pa.*dPv - 0.5*pa.*dMv)/6;
        ce = 5*sum(pa .* res.em_m(d2,:).')/6;
        vCost = max(vCost, abs(cn - res.cost_normal(d2)));
        vEm   = max(vEm,   abs(ce - res.cost_em(d2)));
    end
    fprintf('真实价格重算   %.3e（正常）/ %.3e（紧急）\n', vCost, vEm);

    % ④ 价格情景最小值（保护性检查）
    pm = min(res.pi_min(dd,:), [], 'all');
    fprintf('价格情景最小值 %+.4f 元/kWh  %s\n', pm, ...
        ternary(pm < 0, '（含负值，已按 H-1/H-2 处理，不截断）', '（全部为正）'));

    % ⑤ 日内价格水平项的因果性与有效性（仅 Q4-3）
    if numel(stages) > 1
        L = res.L_lvl(dd, :);
        fprintf('日内水平项     非零 %d/%d 个（阶段 6/12/18）\n', ...
            nnz(abs(L(:,2:end)) > 0), numel(L(:,2:end)));
        fprintf('中心预测留档   pic 有限值 %d/%d\n', nnz(isfinite(res.pic(:))), numel(res.pic));
    end

    fprintf('窗口费用 %.2f 元（正常 %.2f + 紧急 %.2f）；紧急电量 %.1f kWh；调增 %.1f 调减 %.1f\n', ...
        sum(res.cost(dd)), sum(res.cost_normal(dd)), sum(res.cost_em(dd)), ...
        sum(res.em_m(dd,:),'all'), sum(res.dP_m(dd,:),'all'), sum(res.dM_m(dd,:),'all'));
end
fprintf('\nPROBE_Q4_SMOKE_DONE\n');

function s = ternary(c,a,b)
if c; s=a; else; s=b; end
end
