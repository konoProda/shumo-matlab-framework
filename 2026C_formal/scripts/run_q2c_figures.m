function run_q2c_figures()
%% run_q2c_figures —— 问题二（Q2c）图件批量生成
%
%   用法（在 2026C_formal/ 目录下）：
%       matlab -batch "addpath('scripts'); run_q2c_figures"
%   或在 MATLAB 命令行：
%       addpath('scripts'); run_q2c_figures
%
%   说明：按清单顺序逐个执行 figures/问题二/<NN 图名>/plot_q2c_*.m，
%         单张失败不影响其余图；脚本自身带 clear，故用 evalin 派发到 base
%         工作区执行，保证本函数的循环状态不被清空。
%   产出：各图件文件夹内的 PNG / PDF（文件名即交付中文名）。

PROJ_ROOT = fileparts(fileparts(mfilename('fullpath')));
FIG_ROOT  = fullfile(PROJ_ROOT, 'figures', '问题二');

% 图件清单：{文件夹名, 脚本名}（精简版 6 张；作废口径的 11 张已移入 _初版11张_勿引用/）
FIG = { ...
    '01 全年逐日购电结构',           'plot_q2c_year'; ...
    '02 日末储电量轨迹',             'plot_q2c_soc'; ...
    '03 指定日期_计划购电与紧急购电', 'plot_q2c_keydate'; ...
    '04 紧急购电_逐时分布',          'plot_q2c_emhour'; ...
    '05 对照与灵敏度_四面板',        'plot_q2c_compare'; ...
    '06 预测精度_校正前后',          'plot_q2c_mae'};

n  = size(FIG, 1);
ok = false(n, 1);
fprintf('问题二（Q2c）图件批量生成：共 %d 张，根目录 %s\n', n, FIG_ROOT);

for k = 1:n
    fdir = fullfile(FIG_ROOT, FIG{k, 1});
    fscr = fullfile(fdir, [FIG{k, 2} '.m']);
    fprintf('[%2d/%2d] %s ... ', k, n, FIG{k, 1});
    if exist(fscr, 'file') ~= 2
        fprintf('跳过：脚本不存在\n');
        continue;
    end
    t0 = tic;
    try
        evalin('base', sprintf('run(''%s'')', fscr));
        ok(k) = true;
        fprintf('完成（%.1f s）\n', toc(t0));
    catch err
        fprintf('失败（%.1f s）：%s\n', toc(t0), err.message);
    end
end

% 汇总：逐图确认 PNG / PDF 是否落盘
fprintf('\n---- 汇总：成功 %d / %d ----\n', nnz(ok), n);
for k = 1:n
    fdir = fullfile(FIG_ROOT, FIG{k, 1});
    png  = dir(fullfile(fdir, '*.png'));
    pdf  = dir(fullfile(fdir, '*.pdf'));
    if isempty(png) || isempty(pdf)
        fprintf('  [缺图] %-26s png=%d pdf=%d\n', FIG{k, 1}, numel(png), numel(pdf));
    else
        fprintf('  [完成] %-26s %s（%.0f KB）\n', FIG{k, 1}, png(1).name, png(1).bytes / 1024);
    end
end
end
