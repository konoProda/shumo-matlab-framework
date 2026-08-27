function res4 = q4_female_abnormal_judge(female, cfg)
% 问题四：女胎异常判定方法（Q4-1~Q4-9）
% 输入: female preprocess 输出的女胎结构体（rec 记录层）
%       cfg    主程序参数结构体（rho_gc/recall_min）
% 输出: res4 结构体: comp（6 项标准化评分分量）、abn_score（等权）与 S_pca（PCA 权重）、
%       theta_opt（Youden 主准则）与 theta_hi_recall（偏召回补充阈值）、
%       混淆矩阵与五指标（等权/PCA/偏召回）、类型判定结果、BMI 四分位分层误判/漏判率
% 落盘: outputs/tables/q4_*.csv、figures/q4_*.png|eps

rec = female.rec;
n = height(rec);
y_true = rec.abn_label;

%% (1) 偏离型分量与 min-max 标准化（Q4-2~Q4-4）
nz13 = norm01(abs(rec.z13));
nz18 = norm01(abs(rec.z18));
nz21 = norm01(abs(rec.z21));
nzx = norm01(abs(rec.zx));
d_gc = norm01(abs(rec.gc - mean(rec.gc, 'omitnan')));
nL = norm01(rec.raw_reads);
nM = norm01(rec.map_rate);
nN = norm01(rec.dup_rate);
nO = norm01(rec.unique_reads);
nAA = norm01(rec.filter_ratio);
d_read = mean([1 - nL, 1 - nM, nN, 1 - nO, nAA], 2);   % Q4-4
comp = [nz13, nz18, nz21, nzx, d_gc, d_read];
res4.comp = comp;

%% (2) 综合异常评分（Q4-5）: 等权主结果 + PCA 权重对比
w_eq = ones(6, 1) / 6;
S = comp * w_eq;
[coef_pca, ~, ~, ~, explained] = pca(zscore(comp));
w_pca = abs(coef_pca(:, 1));
w_pca = w_pca / sum(w_pca);
S_pca = comp * w_pca;
res4.w_eq = w_eq;
res4.w_pca = w_pca;
res4.var_explained = explained(1);
res4.abn_score = S;
res4.S_pca = S_pca;

%% (3) 阈值遍历与 Youden 主准则（Q4-6）
[th_list, youden, f1_curve, se_curve, sp_curve] = sweep_threshold(S, y_true);
[~, bi] = max(youden);
bi = find(youden == youden(bi), 1, 'last');   % 同分取召回率更高的较低阈值
theta_opt = th_list(bi);
res4.th_list = th_list;
res4.youden = youden;
res4.f1_curve = f1_curve;
res4.se_curve = se_curve;
res4.sp_curve = sp_curve;
res4.theta_opt = theta_opt;

% 偏召回补充阈值（Q4-6）: 召回率 ≥ recall_min 的前提下特异度最高；不可达时取最大召回阈值
feas_rec = se_curve >= cfg.recall_min;
if any(feas_rec)
    [~, bi2] = max(sp_curve(feas_rec));
    idx_feas = find(feas_rec);
    theta_hi = th_list(idx_feas(bi2));
else
    [~, bi2] = max(se_curve);
    theta_hi = th_list(bi2);
end
res4.theta_hi_recall = theta_hi;

%% (4) 混淆矩阵与评价指标（Q4-8）
pred_opt = S >= theta_opt;
[cm, m_opt] = metrics_at(pred_opt, y_true);
[~, m_hi] = metrics_at(S >= theta_hi, y_true);
[~, m_pca] = metrics_at(S_pca >= select_best_threshold(S_pca, y_true), y_true);
res4.cm = cm;
res4.metrics = m_opt;
res4.metrics_hi_recall = m_hi;
res4.metrics_pca = m_pca;
res4.theta_pca = select_best_threshold(S_pca, y_true);
res4.abn_label = y_true;
res4.pred_abn = pred_opt;

%% (5) 异常类型判定（Q4-7，ρ=1，复合判据 S_second≥0.8·S_max）
res4.nz13 = nz13;
res4.nz18 = nz18;
res4.nz21 = nz21;
res4.ngc13 = norm01(abs(rec.gc13 - mean(rec.gc13, 'omitnan')));
res4.ngc18 = norm01(abs(rec.gc18 - mean(rec.gc18, 'omitnan')));
res4.ngc21 = norm01(abs(rec.gc21 - mean(rec.gc21, 'omitnan')));
type_pred = type_judge(res4.nz13, res4.nz18, res4.nz21, ...
    res4.ngc13, res4.ngc18, res4.ngc21, cfg.rho_gc, S >= theta_opt);
res4.type_pred = type_pred;
res4.type_score = [res4.nz13 + cfg.rho_gc * res4.ngc13, ...
                   res4.nz18 + cfg.rho_gc * res4.ngc18, ...
                   res4.nz21 + cfg.rho_gc * res4.ngc21];

%% (6) BMI 四分位分层误判/漏判率（Q4-9）
pred = S >= theta_opt;
bmi_valid = ~isnan(rec.bmi);
edges_q = prctile(rec.bmi(bmi_valid), [25 50 75]);
layer = discretize(rec.bmi, [-inf, edges_q, inf]);
res4.bmi_edges_q = edges_q;
res4.bmi_layer = layer;
layer_rows = cell(4, 7);
for li = 1:4
    mask = layer == li;
    tp = sum(mask & pred & y_true);
    fp = sum(mask & pred & ~y_true);
    fn = sum(mask & ~pred & y_true);
    tn = sum(mask & ~pred & ~y_true);
    miss_rate = fn / (tp + fn);
    false_rate = fp / (fp + tn);
    if tp + fn == 0, miss_rate = NaN; end
    if fp + tn == 0, false_rate = NaN; end
    layer_rows(li, :) = {li, nnz(mask), tp, fp, fn, miss_rate, false_rate};
end
res4.layer_rows = layer_rows;

%% (7) 结果表与图件
write_q4_tables(res4, cfg);
plot_q4_figures(res4, cfg);
end

function [cm, m] = metrics_at(pred, y_true)
% Q4-8: 混淆矩阵与 Accuracy/Recall/Precision/F1/Specificity
tp = sum(pred & y_true);
fp = sum(pred & ~y_true);
fn = sum(~pred & y_true);
tn = sum(~pred & ~y_true);
cm = [tp, fp; fn, tn];
acc = (tp + tn) / numel(y_true);
rec = tp / (tp + fn);
prec = tp / (tp + fp);
f1 = 2 * prec * rec / (prec + rec);
spec = tn / (tn + fp);
if tp + fn == 0, rec = NaN; end
if tp + fp == 0, prec = NaN; f1 = NaN; end
m = struct('acc', acc, 'rec', rec, 'prec', prec, 'f1', f1, 'spec', spec);
end

function [th_list, youden, f1_curve, se_curve, sp_curve] = sweep_threshold(S, y_true)
% 在评分取值网格上遍历阈值，输出 Youden/F1/Se/Sp 曲线（Q4-6）
th_list = sort([unique(S); max(S) + 1; min(S) - 1], 'descend');
n_th = numel(th_list);
se_curve = nan(n_th, 1);
sp_curve = nan(n_th, 1);
f1_curve = nan(n_th, 1);
for ti = 1:n_th
    pred = S >= th_list(ti);
    tp = sum(pred & y_true);
    fp = sum(pred & ~y_true);
    fn = sum(~pred & y_true);
    tn = sum(~pred & ~y_true);
    se_curve(ti) = tp / (tp + fn);
    sp_curve(ti) = tn / (tn + fp);
    prec = tp / (tp + fp);
    rec = se_curve(ti);
    if tp == 0, f1_curve(ti) = 0;
    else, f1_curve(ti) = 2 * prec * rec / (prec + rec); end
end
youden = se_curve + sp_curve - 1;
end

function theta = select_best_threshold(S, y_true)
[th_list, youden] = sweep_threshold(S, y_true);
[~, bi] = max(youden);
bi = find(youden == youden(bi), 1, 'last');
theta = th_list(bi);
end

function type_pred = type_judge(nz13, nz18, nz21, ngc13, ngc18, ngc21, rho, abn_mask)
% Q4-7: 对已判异常样本做类型判定，S_second ≥ 0.8·S_max 报复合异常
S13 = nz13 + rho * ngc13;
S18 = nz18 + rho * ngc18;
S21 = nz21 + rho * ngc21;
n = numel(S13);
type_pred = repmat("", n, 1);
for i = find(abn_mask)'
    [sv, so] = sort([S13(i), S18(i), S21(i)], 'descend');
    names = ["T13", "T18", "T21"];
    if sv(1) > 0 && sv(3) >= 0.8 * sv(1)
        type_pred(i) = strjoin(names(sort(so)), "");
    elseif sv(1) > 0 && sv(2) >= 0.8 * sv(1)
        type_pred(i) = strjoin(names(sort(so(1:2))), "");
    else
        type_pred(i) = names(so(1));
    end
end
end

function v = norm01(x)
% min-max 标准化到 [0,1]；常数列返回全 0.5 避免除零
r = max(x) - min(x);
if r == 0
    v = zeros(size(x));
else
    v = (x - min(x)) / r;
end
end

function write_q4_tables(res4, cfg)
rec_label = res4.cm;
% 标签分布表
m_tbl = table({'总样本数'; '异常样本数'; '正常样本数'}, ...
    [rec_label(1,1)+rec_label(1,2)+rec_label(2,1)+rec_label(2,2); ...
     rec_label(1,1)+rec_label(2,1); rec_label(1,2)+rec_label(2,2)], ...
    'VariableNames', {'项目', '数量'});
writetable(m_tbl, fullfile(cfg.tbl_dir, 'q4_label_dist.csv'));

% 权重表（Q4-5）
comp_names = {'|Z13|', '|Z18|', '|Z21|', '|ZX|', 'GC偏离', '读段质量风险'};
w_tbl = table(comp_names', res4.w_eq, res4.w_pca, ...
    'VariableNames', {'分量', '等权权重', 'PCA权重'});
writetable(w_tbl, fullfile(cfg.tbl_dir, 'q4_weights.csv'));

% 阈值与评价指标表（Q4-6/Q4-8）
th_tbl = table({'Youden主阈值'; '偏召回补充阈值'; 'PCA权重阈值'}, ...
    [res4.theta_opt; res4.theta_hi_recall; res4.theta_pca], ...
    'VariableNames', {'阈值类型', 'θ'});
writetable(th_tbl, fullfile(cfg.tbl_dir, 'q4_threshold_table.csv'));

mm = {'等权评分(Youden阈值)', res4.metrics; '等权评分(偏召回阈值)', res4.metrics_hi_recall; ...
    'PCA权重评分', res4.metrics_pca};
m_rows = cell(3, 5);
for i = 1:3
    m_rows(i, :) = {mm{i, 1}, mm{i, 2}.acc, mm{i, 2}.rec, mm{i, 2}.prec, mm{i, 2}.f1};
end
m_tbl = cell2table(m_rows, 'VariableNames', {'方案', '准确率', '召回率', '精确率', 'F1'});
writetable(m_tbl, fullfile(cfg.tbl_dir, 'q4_cm_metrics.csv'));

% 类型判定结果表（Q4-7）
type_pred = res4.type_pred;
type_names = ["T13", "T18", "T21", "T13T18", "T13T21", "T18T21", "T13T18T21"];
t_rows = {};
for ti = 1:numel(type_names)
    cnt = sum(type_pred == type_names(ti));
    if cnt > 0
        t_rows(end+1, :) = {type_names(ti), cnt};
    end
end
type_tbl = cell2table(t_rows, 'VariableNames', {'预测类型', '预测数量'});
writetable(type_tbl, fullfile(cfg.tbl_dir, 'q4_type_result.csv'));

% BMI 四分位分层表（Q4-9）
layer_tbl = cell2table(res4.layer_rows, 'VariableNames', ...
    {'BMI层', '样本数', '真阳', '假阳', '假阴', '漏判率', '误判率'});
writetable(layer_tbl, fullfile(cfg.tbl_dir, 'q4_bmi_layer.csv'));
end

function plot_q4_figures(res4, cfg)
% 评分分布（按实际标签分层直方图）
S = res4.abn_score;
lab = res4.abn_label;
fig = figure('Visible', 'off');
histogram(S(lab == 0), 'Normalization', 'probability', ...
    'FaceColor', [0.16 0.36 0.75], 'EdgeAlpha', 0.3, 'BinWidth', 0.03);
hold on;
histogram(S(lab == 1), 'Normalization', 'probability', ...
    'FaceColor', [0.85 0.33 0.30], 'EdgeAlpha', 0.3, 'BinWidth', 0.03);
xlabel('异常评分S'); ylabel('占比');
legend({'实际正常', '实际异常'}, 'Location', 'best');
title('异常评分分布');
fig_export(fig, cfg.fig_dir, 'q4_score_hist');

% 阈值-评价指标曲线（Q4-6，点足够多可画曲线）
fig = figure('Visible', 'off');
yyaxis left;
plot(res4.th_list, res4.f1_curve, '-', 'Color', [0.30 0.60 0.45], 'LineWidth', 1.5);
ylabel('F1');
yyaxis right;
plot(res4.th_list, res4.youden, '-', 'Color', [0.85 0.33 0.30], 'LineWidth', 1.5);
ylabel('Youden指数');
xlabel('阈值θ');
title('F1 与 Youden 指数随阈值变化');
legend({'F1', 'Youden指数'}, 'Location', 'best');
fig_export(fig, cfg.fig_dir, 'q4_threshold_curve');

% 混淆矩阵热力图（Q4-8，数值标注）
cm = res4.cm;
fig = figure('Visible', 'off');
imagesc(cm);
colorbar;
set(gca, 'XTick', [1 2], 'XTickLabel', {'预测异常', '预测正常'}, ...
    'YTick', [1 2], 'YTickLabel', {'实际异常', '实际正常'}, 'FontSize', 10);
for i = 1:2
    for j = 1:2
        text(j, i, sprintf('%d', cm(i, j)), 'HorizontalAlignment', 'center', ...
            'FontSize', 12, 'Color', [0.95 0.95 0.95]);
    end
end
title('混淆矩阵');
fig_export(fig, cfg.fig_dir, 'q4_cm_heatmap');
end
