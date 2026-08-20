function param = func_build_params(plot_area, plot_type, crop_type, stat_raw, plant_raw, omega_list)
% func_build_params —— 参数查表与衍生量构建（映射表 P1-1~P1-7）
% 输入: 地块/作物/统计/2023种植数据（func_load_data、func_build_omega 输出）
% 输出: param.omega_list  Nx3 适宜种植三元组（透传）
%       param.plot_area   54x1 地块面积（P1-1）
%       param.plot_type_id 54x1 地块类型编号（1平旱地 2梯田 3山坡地 4水浇地 5普通大棚 6智慧大棚）
%       param.yield_i / cost_i / price_i  Nx1 亩产/成本/单价（P1-2~P1-4，按Ω行取）
%       param.demand_2023  41x2 预期销售量 D_{j,s}（P1-5，2023同季全村总产量）
%       param.n_plot_max   41x1 分散度上限 N_j^max（P1-7）
% 处理: 价格区间文本 -> 均值；智慧大棚第一季平补=普通大棚第一季（假设3）

type_list = {'平旱地', '梯田', '山坡地', '水浇地', '普通大棚', '智慧大棚'};
n_type = 6;
Y = nan(41, n_type, 2);   % 亩产量（P1-2）
C = nan(41, n_type, 2);   % 种植成本（P1-3）
P = nan(41, n_type, 2);   % 销售单价（P1-4）

for r = 1:height(stat_raw)
    j = stat_raw.('作物编号')(r);
    k = find(strcmp(type_list, strtrim(char(stat_raw.('地块类型')(r)))), 1);
    s = 1 + strcmp(char(stat_raw.('种植季次')(r)), '第二季');   % 单季/第一季->1，第二季->2
    Y(j, k, s) = stat_raw.('亩产量/斤')(r);
    C(j, k, s) = stat_raw.('种植成本/(元/亩)')(r);
    P(j, k, s) = parse_price(stat_raw.('销售单价/(元/斤)')(r));
end

% 智慧大棚第一季平补（假设3）：用普通大棚第一季同作物数据
smart_s1 = isnan(Y(:, 6, 1));
Y(smart_s1, 6, 1) = Y(smart_s1, 5, 1);
C(smart_s1, 6, 1) = C(smart_s1, 5, 1);
P(smart_s1, 6, 1) = P(smart_s1, 5, 1);

% 地块类型编号
plot_type_id = zeros(numel(plot_type), 1);
for k = 1:n_type
    plot_type_id(strcmp(plot_type, type_list{k})) = k;
end

% 按 Ω 行取参数（P1-2~P1-4）
N = size(omega_list, 1);
yield_i = zeros(N, 1);  cost_i = zeros(N, 1);  price_i = zeros(N, 1);
for idx = 1:N
    i = omega_list(idx, 1);  j = omega_list(idx, 2);  s = omega_list(idx, 3);
    k = plot_type_id(i);
    assert(~isnan(Y(j, k, s)), '参数缺失: 地块%d 作物%d 季%d', i, j, s);
    yield_i(idx) = Y(j, k, s);
    cost_i(idx)  = C(j, k, s);
    price_i(idx) = P(j, k, s);
end

% D_{j,s}（P1-5）：2023 同季全村总产量 = Σ 种植面积 x 对应亩产
plot_name = build_plot_names();
name2idx = containers.Map(plot_name, 1:54);
demand_2023 = zeros(41, 2);
for r = 1:height(plant_raw)
    i = name2idx(char(plant_raw.plot_name(r)));
    j = plant_raw.crop_id(r);
    s = plant_raw.s(r);
    demand_2023(j, s) = demand_2023(j, s) + plant_raw.area(r) * Y(j, plot_type_id(i), s);
end

% N_j^max（P1-7）：粮食类4 / 水稻3 / 蔬菜瓜果8 / 食用菌6
n_plot_max = zeros(41, 1);
n_plot_max(1:15)  = 4;
n_plot_max(16)    = 3;
n_plot_max(17:37) = 8;
n_plot_max(38:41) = 6;

param = struct('omega_list', omega_list, 'plot_area', plot_area, ...
               'plot_type_id', plot_type_id, 'yield_i', yield_i, ...
               'cost_i', cost_i, 'price_i', price_i, ...
               'demand_2023', demand_2023, 'n_plot_max', n_plot_max);
end

function p = parse_price(txt)
% 价格区间文本 "min-max" -> 均值（D4）
parts = strsplit(strtrim(char(txt)), '-');
p = (str2double(parts{1}) + str2double(parts{2})) / 2;
end

function names = build_plot_names()
% 附件1 顺序生成地块名（A1-A6, B1-B14, C1-C6, D1-D8, E1-E16, F1-F4）
names = [strcat('A', string(1:6)), strcat('B', string(1:14)), strcat('C', string(1:6)), ...
         strcat('D', string(1:8)), strcat('E', string(1:16)), strcat('F', string(1:4))];
names = cellstr(names);
end
