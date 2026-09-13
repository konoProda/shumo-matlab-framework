% run_postprocess.m —— 后处理总调度：图件数据 → 说明文本 → 报告 → 结果表 → 出图
%
%   把全部收尾工作放在**一次 MATLAB 会话**里顺序完成，避免反复启停（3 GB 环境）。
%   两个坑（本轮踩过）：
%     ① 各步骤脚本的路径必须用**绝对路径**，否则会按当前目录再拼一层；
%     ② 出图脚本开头有 `clear`，会在调用者工作区里清掉循环变量 ⇒
%        必须在**独立函数**里 run，`clear` 只清该函数自己的工作区。
%
%   用法：matlab -batch "run('scripts/run_postprocess.m')"

PROJ_ROOT = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
OUT = fullfile(PROJ_ROOT, 'outputs');
fid = fopen(fullfile(OUT, 'log_postprocess.txt'), 'a');
lg = @(varargin) fprintf(fid, varargin{:});

lg('\n%s\n', repmat('=', 1, 72));
lg('后处理开始 %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

steps = { ...
  '图件数据（问题三）',   'prep_q3b_figdata.m'; ...
  '图件数据（问题四）',   'prep_q4_figdata.m'; ...
  '交付说明文本',         'make_deliver_text.m'; ...
  '结果表 xlsx',          'write_q3b_q4_deliver.m'; ...
  '报告章节',             'write_q3b_q4_report.m'};

% 各步骤也在独立函数里 run：脚本内部的循环变量会覆盖调用者的循环变量（本轮踩过）
for istep = 1:size(steps,1)
    lg('\n--- %s ---\n', steps{istep,1});
    f = fullfile(PROJ_ROOT, 'scripts', steps{istep,2});
    ok = safe_run(f, lg);
    if ok; lg('[完成] %s\n', steps{istep,1}); else; lg('[失败] %s\n', steps{istep,1}); end
end

%% 出图：一图一文件夹，脚本自包含；在独立函数里 run 以免被其 clear 波及
%  ★ 2026-09-13 修两处：
%   ① 原先只遍历问题三/问题四，问题一与问题二的图**不在复现链里**
%      ——main_q1 一旦重跑（会重写其 data.csv），问题一的 PNG 就会比数据旧而无人重出；
%      现改为四问全遍历。`dir` 每层只展开一级，故各问 `_勿引用/` 子目录不会被误出图。
%   ② **只重出"数据比图新"的图**：绘制脚本只读 data.csv 不做计算，data.csv 没动
%      就不必重画（2026-09-13 编程手要求提速）。PNG 与 data.csv 同目录，直接比时间戳。
nOK = 0;  nAll = 0;  nSkip = 0;
for q = {'问题一', '问题二', '问题三', '问题四'}
    d = dir(fullfile(PROJ_ROOT, 'figures', q{1}, '*', 'plot_*.m'));
    lg('\n--- 出图（%s，%d 张）---\n', q{1}, numel(d));
    for i = 1:numel(d)
        fpath = fullfile(d(i).folder, d(i).name);
        nAll = nAll + 1;
        if is_stale(d(i).folder)
            if safe_run(fpath, lg)
                nOK = nOK + 1;
            end
        else
            nSkip = nSkip + 1;
            lg('[跳过] %s（data.csv 未更新，图无需重出）\n', d(i).name);
        end
    end
end

lg('\n后处理结束 %s（出图 %d / %d，跳过 %d，失败 %d）\n', datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
   nOK, nAll, nSkip, nAll - nOK - nSkip);
fclose(fid);
fprintf('POSTPROCESS_DONE  出图 %d / %d，跳过 %d\n', nOK, nAll, nSkip);

% ---------------------------------------------------------------- 局部函数
function tf = is_stale(fig_dir)
%IS_STALE  该图是否需要重出：目录内存在 PNG 且其时间戳早于 data.csv 时为真。
%   缺 PNG 或 data.csv 时一律视为需要重出（宁可多画一次）。
d = dir(fullfile(fig_dir, '*.png'));
c = fullfile(fig_dir, 'data.csv');
if isempty(d) || exist(c, 'file') ~= 2
    tf = true;  return
end
tf = any([d.datenum] < dir(c).datenum);
end

function ok = safe_run(fpath, lg)
% 在独立函数工作区里 run，使脚本开头的 clear 不影响调用者。
% 注意：被 run 的脚本里若有 clear，会清掉本函数的局部变量，
% 因此 ok 必须在 run **之后**赋值，catch 里也不能引用局部变量。
try
    run(fpath);
    ok = true;
catch ME
    ok = false;
    fprintf(2, '[safe_run 失败] %s\n', ME.message);
end
end
