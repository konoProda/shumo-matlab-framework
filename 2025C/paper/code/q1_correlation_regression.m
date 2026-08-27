function res1 = q1_correlation_regression(male, cfg)
% 问题一：Y 浓度相关特性与关系模型（Q1-1~Q1-6）
% 输入: male preprocess 输出的男胎结构体（rec 记录层 / subj 孕妇层）
%       cfg  主程序参数结构体
% 输出: res1 结构体: corr_vec/corr_pval、base/int/quad/hw 四个回归模型
%       （系数/标准误/t值/p值/R²等）、model_selected 与 sigma_resid（N8/Q1-6）、
%       剔除 AB 非空记录的对比结果 comp_ab
% 落盘: outputs/tables/q1_*.csv、figures/q1_*.png|eps

rec = male.rec;
y = rec.y_conc;
t = rec.gest_week;
bmi = rec.bmi;
age = rec.age;
height = rec.height;
weight = rec.weight;
gc = rec.gc;
filter = rec.filter_ratio;

%% (1) 相关分析（Q1-1）
M = [y, t, bmi, age, weight, gc, filter];
ok = all(isfinite(M), 2);
M = M(ok, :);
n_ok = size(M, 1);
R = corrcoef(M);
r_vec = R(1, 2:end)';
tstat = r_vec .* sqrt((n_ok - 2) ./ (1 - r_vec.^2));
p_vec = 2 * tcdf(-abs(tstat), n_ok - 2);
res1.corr_vec = r_vec;
res1.corr_pval = p_vec;

%% (2) 回归模型（Q1-2 基础 / Q1-3 交互 / Q1-4 二次 / Q1-5 身高体重对照）
one = ones(n_ok, 1);
res1.base = func_ols([one, M(:,2), M(:,3), M(:,4), M(:,6), M(:,7)], M(:,1));                       % Q1-2
res1.int  = func_ols([one, M(:,2), M(:,3), M(:,2).*M(:,3), M(:,4), M(:,6), M(:,7)], M(:,1));      % Q1-3
res1.quad = func_ols([one, M(:,2), M(:,3), M(:,2).^2, M(:,3).^2, M(:,2).*M(:,3)], M(:,1));        % Q1-4

ok_hw = all(isfinite([y, t, height, weight, age, gc, filter]), 2);
Mhw = [y(ok_hw), t(ok_hw), height(ok_hw), weight(ok_hw), age(ok_hw), gc(ok_hw), filter(ok_hw)];
res1.hw = func_ols([ones(size(Mhw,1), 1), Mhw(:, 2:end)], Mhw(:, 1));                              % Q1-5

%% (3) 主模型选择与 σ（N8 / Q1-6）: 默认交互模型，交互项不显著且调整R²未提升则用基础模型
p_int_term = res1.int.p_val(4);   % t·BMI 交互项
if p_int_term < 0.05 || res1.int.r2_adj > res1.base.r2_adj
    res1.model_selected = 'int';
    res1.sigma_resid = res1.int.sigma;
else
    res1.model_selected = 'base';
    res1.sigma_resid = res1.base.sigma;
end

%% (4) 剔除 AB 非空记录的对比（B8）
keep_ab = ismissing(rec.ab_str) | rec.ab_str == "";
M2 = [y, t, bmi, age, gc, filter];
M2 = M2(keep_ab & all(isfinite(M2), 2), :);
res1.comp_ab = func_ols([ones(size(M2,1), 1), M2(:, 2:end)], M2(:, 1));

%% (5) 结果表落盘
write_q1_tables(res1, M, n_ok, cfg);

%% (6) 图件
plot_q1_figures(M, R, res1, cfg);
end

function write_q1_tables(res1, M, n_ok, cfg)
var_names = {'孕周', 'BMI', '年龄', '体重', 'GC含量', '过滤比例'};

% 描述统计表
stats = [M(:, 2:end), M(:, 1)];   % t/bmi/age/weight/gc/filter/y
names_all = [var_names, {'Y浓度'}];
desc = table(names_all', mean(stats)', std(stats)', min(stats)', max(stats)', median(stats)', ...
    'VariableNames', {'指标', '均值', '标准差', '最小值', '最大值', '中位数'});
writetable(desc, fullfile(cfg.tbl_dir, 'q1_desc_stats.csv'));

% 相关系数表（Q1-1）
corr_tbl = table(var_names', res1.corr_vec, res1.corr_pval, ...
    'VariableNames', {'指标', '相关系数', 'p值'});
writetable(corr_tbl, fullfile(cfg.tbl_dir, 'q1_corr_table.csv'));

% 回归系数与显著性表（Q1-2~Q1-5）
model_specs = {'base', {'截距','孕周','BMI','年龄','GC含量','过滤比例'}; ...
               'int',  {'截距','孕周','BMI','t×BMI','年龄','GC含量','过滤比例'}; ...
               'quad', {'截距','孕周','BMI','t²','BMI²','t×BMI'}; ...
               'hw',   {'截距','孕周','身高','体重','年龄','GC含量','过滤比例'}};
reg_rows = {};
for mi = 1:size(model_specs, 1)
    md = res1.(model_specs{mi, 1});
    for ci = 1:numel(md.beta)
        reg_rows(end+1, :) = {model_specs{mi, 1}, model_specs{mi, 2}{ci}, ...
            md.beta(ci), md.se(ci), md.t_stat(ci), md.p_val(ci)};
    end
end
reg_tbl = cell2table(reg_rows, 'VariableNames', {'模型', '变量', '系数', '标准误', 't值', 'p值'});
writetable(reg_tbl, fullfile(cfg.tbl_dir, 'q1_reg_table.csv'));

% 拟合优度表
good = table('Size', [0 6], 'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'模型', 'R2', '调整R2', 'F值', 'F检验p值', '残差标准差'});
for mi = 1:size(model_specs, 1)
    md = res1.(model_specs{mi, 1});
    good(mi, :) = {model_specs{mi, 1}, md.r2, md.r2_adj, md.f_stat, md.f_p, md.sigma};
end
writetable(good, fullfile(cfg.tbl_dir, 'q1_goodness.csv'));

% 剔除 AB 非空对比表（B8）: 基础模型全样本 vs 子集
md_sub = res1.comp_ab;
ab_tbl = table({'截距';'孕周';'BMI';'年龄';'GC含量';'过滤比例'}, ...
    res1.base.beta, md_sub.beta, ...
    'VariableNames', {'变量', '全样本系数', '剔除AB系数'});
writetable(ab_tbl, fullfile(cfg.tbl_dir, 'q1_ab_compare.csv'));
end

function plot_q1_figures(M, R, res1, cfg)
y = M(:, 1); t = M(:, 2); bmi = M(:, 3);

% Y 浓度-孕周散点图
fig = figure('Visible', 'off');
scatter(t, y, 12, [0.16 0.36 0.75], 'filled', 'MarkerFaceAlpha', 0.35);
xlabel('检测孕周(周)'); ylabel('Y染色体浓度');
title('Y染色体浓度随孕周分布');
fig_export(fig, cfg.fig_dir, 'q1_scatter_gest');

% Y 浓度-BMI 散点图
fig = figure('Visible', 'off');
scatter(bmi, y, 12, [0.13 0.55 0.35], 'filled', 'MarkerFaceAlpha', 0.35);
xlabel('孕妇BMI'); ylabel('Y染色体浓度');
title('Y染色体浓度随BMI分布');
fig_export(fig, cfg.fig_dir, 'q1_scatter_bmi');

% 相关性热力图（Q1-1，标注数值由矩阵现场计算）
var_names = {'Y浓度', '孕周', 'BMI', '年龄', '体重', 'GC含量', '过滤比例'};
fig = figure('Visible', 'off');
imagesc(R); axis square; colorbar; clim([-1 1]);
set(gca, 'XTick', 1:7, 'XTickLabel', var_names, 'YTick', 1:7, 'YTickLabel', var_names, ...
    'XTickLabelRotation', 45, 'FontSize', 8);
for i = 1:7
    for j = 1:7
        text(j, i, sprintf('%.2f', R(i, j)), 'HorizontalAlignment', 'center', 'FontSize', 7);
    end
end
title('Y浓度与各指标相关系数热力图');
fig_export(fig, cfg.fig_dir, 'q1_corr_heatmap');

% 主模型残差图（Q1-6 所选模型）
sel = res1.(res1.model_selected);
fitted = y - sel.resid;   % 主模型与相关分析共用同一批完整个案
fig = figure('Visible', 'off');
scatter(fitted, sel.resid, 12, [0.75 0.35 0.16], 'filled', 'MarkerFaceAlpha', 0.35);
hold on; yline(0, 'k--');
xlabel('拟合值'); ylabel('残差');
title(sprintf('主模型(%s)残差图', res1.model_selected));
fig_export(fig, cfg.fig_dir, 'q1_resid');

% 残差直方图
fig = figure('Visible', 'off');
histogram(sel.resid, 30, 'FaceColor', [0.75 0.35 0.16], 'EdgeAlpha', 0.3);
xlabel('残差'); ylabel('频数');
title('主模型残差分布');
fig_export(fig, cfg.fig_dir, 'q1_resid_hist');
end
