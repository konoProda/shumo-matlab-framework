% sweep_q3_sat.m — 方案b扫描: 各品类需求满足率下限对问题3利润的影响
% 运行: matlab -batch "run('2023c/scripts/sweep_q3_sat.m')"
% 输出: outputs/q3_sat_sweep.csv + 屏幕汇总表
script_full = mfilename('fullpath');
if ~startsWith(script_full, filesep), script_full = fullfile(pwd, script_full); end
PROJ_ROOT = fileparts(fileparts(script_full));
addpath(fullfile(PROJ_ROOT, 'src'));
OUT_DIR = fullfile(PROJ_ROOT, 'outputs');

opts = detectImportOptions(fullfile(OUT_DIR, 'product_info.csv'), 'TextType', 'string');
opts.VariableNames = {'prod_code', 'prod_name', 'class_code', 'class_name', 'loss'};
opts.VariableTypes = {'string', 'string', 'string', 'string', 'double'};
prod_info = readtable(fullfile(OUT_DIR, 'product_info.csv'), opts);
stats_q1 = func_q1_statistics(prod_info, PROJ_ROOT, false);   % 跳过绘图加速

bounds = [0, 0.10, 0.20, 0.30, 0.40, 0.50];
n_rows = numel(bounds);
res_lb   = zeros(n_rows, 1);
res_nsel = zeros(n_rows, 1);
res_prof = nan(n_rows, 1);
res_sat  = nan(n_rows, 6);
for k = 1:n_rows
    b = bounds(k);
    fprintf('\n===== sat_lb = %.0f%% =====\n', b * 100);
    try
        r = func_q3_item_milp(stats_q1, prod_info, PROJ_ROOT, false, b);
        res_lb(k) = b;
        res_nsel(k) = round(sum(r.y_vec));
        res_prof(k) = r.profit_q3;
        res_sat(k, :) = r.demand_sat';
    catch ME
        fprintf('[sweep] sat_lb=%.0f%% 不可行或出错: %s\n', b * 100, ME.message);
        res_lb(k) = b;
    end
end

fprintf('\n===== 方案b扫描结果汇总 =====\n');
fprintf('下限   上架数   总利润(元)    品类满足率%% [花叶 花菜 水生 茄 辣椒 食用菌]\n');
for k = 1:n_rows
    if isnan(res_prof(k))
        fprintf('%4.0f%%   --       不可行\n', res_lb(k) * 100);
    else
        fprintf('%4.0f%%   %3d     %9.2f    %s\n', res_lb(k) * 100, res_nsel(k), ...
                res_prof(k), mat2str(round(res_sat(k, :) * 100)));
    end
end
tbl = table(string(round(res_lb * 100)) + "%", res_nsel, res_prof, res_sat, ...
    'VariableNames', {'需求满足率下限', '上架数', '总利润元', '品类满足率矩阵'});
writetable(tbl, fullfile(OUT_DIR, 'q3_sat_sweep.csv'), 'Encoding', 'UTF-8');
fprintf('\n扫描结果已保存: outputs/q3_sat_sweep.csv\n');
