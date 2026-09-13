% run_all_figures.m —— 批量重出全部图件
% 组织方式：每张图自包含于 figures/<问题>/<编号 图名>/ 文件夹内
%             （绘图脚本 + data.csv + PNG + PDF 同目录），改图只需打开对应文件夹。
% 用法：matlab -batch "run('src/run_all_figures.m')"

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');

figs = {
    '问题一', '01 典型日计划购电策略',      'plot_q1_price_buy'
    '问题一', '02 储能充放电与储电量',      'plot_q1_soc'
    '问题二', '01 全年购电与弃光',          'plot_q2_year'
    '问题二', '02 储能_逐日与全年对照',      'plot_q2_soc_cmp'
    '问题二', '03 指定日期_购电与储能',      'plot_q2_keydays'
    '问题二', '04 两口径对照_紧急购电与费用',  'plot_q2_dual'
    '问题二', '05 视野灵敏度_费用与紧急购电',  'plot_q2_sens'
    '问题二', '06 三情况日末储电量轨迹',        'plot_q2_soc3'
    '问题二', '07 光伏与负载的月度规律',        'plot_q2_season'
    '问题二', '08 紧急购电的逐时分布',          'plot_q2_hr'
};

fprintf('=== 批量出图（共 %d 张）===\n', size(figs,1));
for k = 1:size(figs, 1)
    d = fullfile(PROJ_ROOT, 'figures', figs{k,1}, figs{k,2});
    assert(exist(fullfile(d, [figs{k,3} '.m']), 'file') == 2, '缺少绘图脚本：%s', figs{k,3});
    fprintf('  [%d/%d] %s / %s\n', k, size(figs,1), figs{k,1}, figs{k,2});
    run_fig(d, figs{k,3});
end
fprintf('全部图件已重出。\n');

function run_fig(d, name)
% 在独立函数工作区内执行绘图脚本：脚本开头的 clear 不会破坏调用方循环
run(fullfile(d, [name '.m']));
end
