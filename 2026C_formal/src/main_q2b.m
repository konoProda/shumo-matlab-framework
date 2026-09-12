% main_q2b.m —— 问题二 第三轮：预测层偏差校正（B0~B3 对照运行）
% 一月按【已知数据】处理：不预测，直接按实际数据逐日制定计划并执行，储能推演到 2 月 1 日；
% 二月起每天 0:00 预测剩余全年（同星期回溯 + 当日分时偏差校正）→ 求计划 LP → 只执行当天。
% 执行层：负载优先实时纠偏（沿用已确认口径，四个方案完全一致）。
% 校正器受"最少 5 个有效残差日"约束，实际自 2 月 6 日起生效；四方案共享同一份一月轨迹。

clear; close all; clc;

%% 路径与参数
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;
H = Inf;

%% 数据
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D  = numel(day_list);
ri = (find(day_list == datetime(2025,2,1)):D).';
d_start = ri(1);

%% 四个对照方案
runs = { 'B0', 0, 0;      % 原同星期预测（新时间口径基线）
         'B1', 1, 0;      % 仅负荷校正
         'B2', 0, 1;      % 仅光伏校正
         'B3', 1, 1 };     % 两者均校正

fprintf('=== 问题二 第三轮：预测层偏差校正（B0~B3）===\n');
fprintf('  时间口径：起始标签 + 电价相位归位 + 首日首槽用典型日补\n');
fprintf('  一月口径：按已知数据处理（不预测），%s 起开始预测\n', char(day_list(d_start), 'yyyy-MM-dd'));
fprintf('  校正：窗口 W=%d 日、最少 %d 个有效残差日、gamma 固定 1（受样本约束，实际自 2 月 6 日起生效）\n', 28, 5);

R = cell(size(runs,1), 1);
t_all = tic;
for k = 1:size(runs,1)
    cfg = struct('on', true, 'gamma_L', runs{k,2}, 'gamma_PV', runs{k,3}, ...
                 'W', 28, 'min_days', 5, 'd_start', d_start);
    fprintf('\n--- %s（gamma_L=%d, gamma_PV=%d）开始 %.1f min ---\n', ...
            runs{k,1}, runs{k,2}, runs{k,3}, toc(t_all)/60);
    res = func_roll_q2(price_v, load_m, pv_m, day_list, L1, PV1, prm, K, H, 'correct', 60, cfg);
    R{k} = res;
    save(fullfile(PROJ_ROOT, 'outputs', sprintf('final_results_q2b_%s.mat', runs{k,1})), ...
         'res', 'prm', 'K', 'H', 'cfg');
    fprintf('--- %s 完成，耗时 %.1f min，全年费用 %.2f 元 ---\n', ...
            runs{k,1}, res.time/60, sum(res.cost));
end
fprintf('\n四个方案全部完成，总耗时 %.1f min\n', toc(t_all)/60);

%% 一月轨迹一致性自检（四方案必须共享同一份一月预热）
E0_1st = cellfun(@(r) r.E0_m(d_start), R);
fprintf('2月1日 日初储电量：%s（极差 %.3e kWh）\n', mat2str(E0_1st.', 10), max(E0_1st) - min(E0_1st));
assert(max(E0_1st) - min(E0_1st) < 1e-9, 'B0~B3 的一月预热轨迹不一致');

%% 对比汇总
load_tot = sum(load_m(ri,:), 'all') * prm.dt;
fprintf('\n%-6s %14s %14s %13s %13s %12s %8s %8s %10s\n', '方案', ...
        '全年费用', '窗口费用', '窗口计划购电', '窗口紧急购电', '紧急电量', '紧急天数', '紧急槽数', '紧急占负荷');
cmp = zeros(size(runs,1), 8);
for k = 1:size(runs,1)
    r = R{k};
    cmp(k,:) = [sum(r.cost), sum(r.cost(ri)), sum(r.cost_plan(ri)), sum(r.cost_em(ri)), ...
                sum(r.em_m(ri,:), 'all'), nnz(sum(r.em_m(ri,:),2) > 1e-6), ...
                nnz(r.em_m(ri,:) > 1e-6), 100*sum(r.em_m(ri,:),'all')/load_tot];
    fprintf('%-6s %14.2f %14.2f %13.2f %13.2f %12.1f %8d %8d %9.3f%%\n', runs{k,1}, cmp(k,:));
end

%% 落盘对比表
T_cmp = table({runs{:,1}}.', cmp(:,1), cmp(:,2), cmp(:,3), cmp(:,4), cmp(:,5), ...
              cmp(:,6), cmp(:,7), cmp(:,8), ...
    'VariableNames', {'plan','cost_year','cost_win','plan_cost_win','em_cost_win', ...
                      'em_kwh_win','em_days','em_slots','em_share_pct'});
writetable(T_cmp, fullfile(PROJ_ROOT, 'outputs', 'q2b_compare.csv'));

fprintf('\n结果已写入 outputs/final_results_q2b_B0..B3.mat、q2b_compare.csv\n');
fprintf('诊断与回传报告由 scripts/report_q2b.m 基于上述 .mat 生成\n');
