function [plot_area, plot_type, crop_type, plant_raw, stat_raw] = func_load_data(data_dir)
% func_load_data —— 附件1/2 数据加载与清洗（映射表 D1~D4）
% 输入: data_dir  数据目录（<题目名>/data/）
% 输出: plot_area  54x1 地块面积（亩，P1-1）
%       plot_type  54x1 cellstr 地块类型（S0-3，顺序即地块编号 1..54）
%       crop_type  41x1 cellstr 作物类型（S0-4）
%       plant_raw  table 2023年种植情况（地块名前向填充，季次已转数值 s）
%       stat_raw   table 2023年统计（已删尾部空行，销售单价保留区间文本）

% ---- D1 附件1 [乡村的现有耕地] ----
T1 = readtable(fullfile(data_dir, '附件1.xlsx'), 'Sheet', '乡村的现有耕地', ...
               'VariableNamingRule', 'preserve');
plot_area = T1.('地块面积/亩');
plot_type = cellstr(T1.('地块类型'));
assert(numel(plot_area) == 54 && all(plot_area > 0), '地块表应为54行且面积为正');

% ---- D2 附件1 [乡村种植的农作物] ----
T2 = readtable(fullfile(data_dir, '附件1.xlsx'), 'Sheet', '乡村种植的农作物', ...
               'VariableNamingRule', 'preserve');
crop_type = cellstr(T2.('作物类型')(1:41));   % 前41行为作物，其后为季次说明行

% ---- D3 附件2 [2023年的农作物种植情况] ----
T3 = readtable(fullfile(data_dir, '附件2.xlsx'), 'Sheet', '2023年的农作物种植情况', ...
               'VariableNamingRule', 'preserve');
plot_col = T3.('种植地块');
for r = 2:numel(plot_col)                     % 合并单元格空值前向填充
    if ismissing(plot_col(r)) || isempty(char(plot_col(r))) || all(isspace(char(plot_col(r))))
        plot_col(r) = plot_col(r - 1);
    end
end
season_col = T3.('种植季次');
s_col = zeros(numel(season_col), 1);          % 单季/第一季 -> 1，第二季 -> 2（S0-6）
s_col(strcmp(season_col, '第二季')) = 2;
s_col(s_col == 0) = 1;
plant_raw = table(plot_col, T3.('作物编号'), T3.('作物名称'), ...
                  T3.('作物类型'), T3.('种植面积/亩'), s_col, ...
                  'VariableNames', {'plot_name', 'crop_id', 'crop_name', 'crop_type', 'area', 's'});

% ---- D4 附件2 [2023年统计的相关数据] ----
T4 = readtable(fullfile(data_dir, '附件2.xlsx'), 'Sheet', '2023年统计的相关数据', ...
               'VariableNamingRule', 'preserve');
stat_raw = T4(~ismissing(T4.('作物编号')), :);   % 删除尾部空行
end
