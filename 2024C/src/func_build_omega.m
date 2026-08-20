function [omega_list, omega_map] = func_build_omega(plot_type, crop_type)
% func_build_omega —— 适宜种植集合 Ω 构建（映射表 S0-7）
% 输入: plot_type 54x1 地块类型；crop_type 41x1 作物类型
% 输出: omega_list  Nx3 = [地块i 作物j 季次s]，N=|Ω|
%       omega_map  54x41x2 logical
% 规则: 平旱地/梯田/山坡地 -> s=1 粮食类1..15（水稻除外）；
%       水浇地 -> s=1 水稻16+蔬菜17..34，s=2 大白菜/白萝卜/红萝卜35..37；
%       普通大棚 -> s=1 蔬菜17..34，s=2 食用菌38..41；
%       智慧大棚 -> s=1,2 蔬菜17..34

assert(numel(crop_type) == 41, '作物类型应为41行');
n_plot = numel(plot_type);
omega_map = false(n_plot, 41, 2);
for i = 1:n_plot
    switch plot_type{i}
        case {'平旱地', '梯田', '山坡地'}
            omega_map(i, 1:15, 1) = true;
        case '水浇地'
            omega_map(i, 16:34, 1) = true;
            omega_map(i, 35:37, 2) = true;
        case '普通大棚'
            omega_map(i, 17:34, 1) = true;
            omega_map(i, 38:41, 2) = true;
        case '智慧大棚'
            omega_map(i, 17:34, 1) = true;
            omega_map(i, 17:34, 2) = true;
        otherwise
            error('未知地块类型: %s', plot_type{i});
    end
end
[ii, jj, ss] = ind2sub(size(omega_map), find(omega_map));
omega_list = [ii(:), jj(:), ss(:)];
end
