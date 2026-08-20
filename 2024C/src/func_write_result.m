function func_write_result(out_dir, tpl_name, sol)
% func_write_result —— 结果回填附件3模板（映射表 D5）
% 输入: out_dir  输出目录（<题目名>/outputs/）
%       tpl_name 模板文件名（result1_1.xlsx / result1_2.xlsx / result2.xlsx）
%       sol  求解结果（sol.x 为 Nx7 种植面积，sol.omega_list 为 Nx3）
% 输出: 模板副本写入 out_dir，仅填 82 数据行（C2:AQ83）的种植亩数，不动其余格式

proj_root = fileparts(out_dir);
tpl_src = fullfile(proj_root, 'data', '附件3', tpl_name);
tpl_dst = fullfile(out_dir, tpl_name);
copyfile(tpl_src, tpl_dst, 'f');

oi = sol.omega_list(:, 1);   oj = sol.omega_list(:, 2);   os = sol.omega_list(:, 3);
x = sol.x;
years = 2024:2030;
second_order = [27:34, 35:50, 51:54];   % 模板第二季行的地块顺序 D1-D8, E1-E16, F1-F4

ids1 = find(os == 1);
ids2 = find(os == 2);
for ti = 1:7
    M1 = zeros(54, 41);                 % 第一季（含单季：单季作物填第一季行，S0-6）
    for k = 1:numel(ids1)
        M1(oi(ids1(k)), oj(ids1(k))) = x(ids1(k), ti);
    end
    M2 = zeros(28, 41);                 % 第二季（D1-D8, E1-E16, F1-F4）
    for k = 1:numel(ids2)
        r = find(second_order == oi(ids2(k)), 1);
        M2(r, oj(ids2(k))) = x(ids2(k), ti);
    end
    M = round([M1; M2], 4);             % 82x41，填写亩数
    writematrix(M, tpl_dst, 'Sheet', num2str(years(ti)), 'Range', 'C2');
end
end
