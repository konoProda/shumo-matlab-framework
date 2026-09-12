% cmp_q2_lexico.m —— 分层目标对照：加权总费用 vs 先保供（最小化紧急购电量）（组内产物，不交付）
%
% 建模手 C3 = A 的附加验证：正式目标仍为"正常购电费 + 5 倍紧急购电费"的加权总费用；
% 本脚本检验一个自然疑问——若改为"先最小化紧急购电量、再最小化费用"的分层目标，
% 最优解是否会不同。
%
% 做法：逐日各解两次同一个视界 LP，只换目标系数：
%   ① 加权总费用（现用）     ② 仅最小化紧急购电电量
% 若两者给出的紧急购电量一致，说明"5 倍惩罚"已足以让费用最优解顺带取到最小紧急购电量，
% 分层目标不改变结果。为控制耗时，本对照只跑前 NDAY 天（视界仍取剩余全年）。
%
% 输出 outputs/q2_lexico_cmp.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
optL = optimoptions('linprog', 'Display', 'off');

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;  NDAY = 90;
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D = size(load_m, 1);

E_now = prm.E_init;  Zc = 0;  Zs = 0;  Hc = 0;  Hs = 0;  ndiff = 0;
rec = zeros(NDAY, 6);
fprintf('=== 分层目标对照（前 %d 天，视界取剩余全年）===\n', NDAY);
for d = 1:NDAY
    [Lh, PVh] = func_forecast_q2(load_m, pv_m, L1, PV1, K, d);
    nH = D - d + 1;
    [fL, ~, ~, ~, AeqL, beqL, lbL, ubL, auxL] = func_build_q2( ...
        repmat(price_v(:), nH, 1), reshape(Lh.',[],1), reshape(PVh.',[],1), E_now, prm, false);

    % ① 加权总费用（现用目标）
    x1 = linprog(fL, [], [], AeqL, beqL, lbL, ubL, optL);
    % ② 仅最小化紧急购电电量：把目标换成紧急购电变量的系数和
    f2 = zeros(size(fL));
    f2([auxL.idx.HL; auxL.idx.HC]) = 1;
    x2 = linprog(f2, [], [], AeqL, beqL, lbL, ubL, optL);

    h1 = sum(x1([auxL.idx.HL; auxL.idx.HC]));
    h2 = sum(x2([auxL.idx.HL; auxL.idx.HC]));
    z2 = fL.' * x2;
    if abs(h1 - h2) > 1e-6; ndiff = ndiff + 1; end
    rec(d,:) = [d, fL.'*x1, h1, z2, h2, h1-h2];
    Zc = Zc + fL.'*x1;  Hc = Hc + h1;  Zs = Zs + z2;  Hs = Hs + h2;

    % 按 ① 的第 d 天计划推进（对照只关心目标形式，执行口径统一用负载优先）
    gx = @(o) x1(o + (0:prm.T-1).');
    o = func_exec_q2(gx(auxL.idx.GL) + gx(auxL.idx.GC), gx(auxL.idx.C), gx(auxL.idx.D), ...
                     gx(auxL.idx.E), load_m(d,:).', pv_m(d,:).', price_v, E_now, prm, 'correct');
    E_now = o.E(end);
end

fprintf('\n%-28s %18s %18s\n', '指标', '① 加权总费用', '② 先最小化紧急电量');
fprintf('%-28s %18.2f %18.2f\n', '视界目标值合计(元)', Zc, Zs);
fprintf('%-28s %18.3f %18.3f\n', '视界紧急购电量合计(kWh)', Hc, Hs);
fprintf('%-28s %18d %18d\n', '两者紧急电量不同的天数', ndiff, ndiff);
fprintf('\n结论：%s\n', string(ndiff == 0));

out = table(rec(:,1), rec(:,2), rec(:,3), rec(:,4), rec(:,5), rec(:,6), ...
    'VariableNames', {'day','cost_obj_yuan','em_kwh_cost_obj','cost_obj2_yuan','em_kwh_lexico','diff_kwh'});
writetable(out, fullfile(PROJ_ROOT, 'outputs', 'q2_lexico_cmp.csv'));
fprintf('已写入 outputs/q2_lexico_cmp.csv\n');
