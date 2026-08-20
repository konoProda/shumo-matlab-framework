function planted_2023 = func_build_anchor(plant_raw, omega_map)
% func_build_anchor —— 2023 年种植锚点构建（映射表 P1-8）
% 输入: plant_raw  2023年种植表（func_load_data 输出，含数值季次 s）
%       omega_map  54x41x2 适宜种植集合（维度核对用）
% 输出: planted_2023  54x41x2 logical，u^2023_{i,j,s}（连作/轮作/前茬先验常数）

assert(isequal(size(omega_map), [54, 41, 2]), 'omega_map 维度应为 54x41x2');
plot_name = build_plot_names();
name2idx = containers.Map(plot_name, 1:54);
planted_2023 = false(54, 41, 2);
for r = 1:height(plant_raw)
    i = name2idx(char(plant_raw.plot_name(r)));
    planted_2023(i, plant_raw.crop_id(r), plant_raw.s(r)) = true;
end
end

function names = build_plot_names()
% 附件1 顺序生成地块名（A1-A6, B1-B14, C1-C6, D1-D8, E1-E16, F1-F4）
names = [strcat('A', string(1:6)), strcat('B', string(1:14)), strcat('C', string(1:6)), ...
         strcat('D', string(1:8)), strcat('E', string(1:16)), strcat('F', string(1:4))];
names = cellstr(names);
end
