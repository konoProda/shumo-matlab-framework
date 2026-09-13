% run_finish.m —— 收尾轮后处理（精简版，2026-09-13 编程手要求提速）
%
%   与 run_postprocess.m 的区别：**跳过图件数据落盘与批量出图**。
%   理由：本轮只有 Q4 的 P0 / Ideal 两组"评价性计算"新增，**图件所依赖的
%   S3 / Q4-2 / Q4-3 三组结果没有变化**，各图 data.csv 已是最终版，重绘纯属重复劳动。
%   真正需要刷新的是三处"读结果文件现算"的产物：
%     ① 四份交付说明文本（q4.txt 会补入 P0 / Ideal 对照段）
%     ② 三张结果表 xlsx
%     ③ IMPLEMENTATION_REPORT / PAPER_HANDOFF 的问题三、四章节（幂等写入）
%
%   跑完本脚本后，如需补齐图件（例如改了绘图脚本），再单独跑 run_postprocess.m。
%
%   用法：matlab -batch "run('scripts/run_finish.m')"

PROJ_ROOT = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
OUT = fullfile(PROJ_ROOT, 'outputs');
fid = fopen(fullfile(OUT, 'log_postprocess.txt'), 'a');
lg = @(varargin) fprintf(fid, varargin{:});

lg('\n%s\n', repmat('=', 1, 72));
lg('收尾后处理（跳过图件）开始 %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

steps = { ...
  '交付说明文本',  'make_deliver_text.m'; ...
  '结果表 xlsx',   'write_q3b_q4_deliver.m'; ...
  '报告章节',      'write_q3b_q4_report.m'};

for istep = 1:size(steps,1)
    lg('\n--- %s ---\n', steps{istep,1});
    f = fullfile(PROJ_ROOT, 'scripts', steps{istep,2});
    ok = safe_run(f, lg);
    if ok; lg('[完成] %s\n', steps{istep,1}); else; lg('[失败] %s\n', steps{istep,1}); end
end

%% 仅重出"数据比图新"的图（通常只有问题一那两张：main_q1 重跑会刷新其 data.csv）
%  全量重绘见 run_postprocess.m；本脚本只补过期的那几张，避免无谓机时。
nRe = 0;  nPend = 0;
for q = {'问题一', '问题二', '问题三', '问题四'}
    d = dir(fullfile(PROJ_ROOT, 'figures', q{1}, '*', 'plot_*.m'));
    for i = 1:numel(d)
        if is_stale(d(i).folder)
            nPend = nPend + 1;
            lg('[重出] %s\n', d(i).name);
            if safe_run(fullfile(d(i).folder, d(i).name), lg); nRe = nRe + 1; end
        end
    end
end
lg('\n过期图重出 %d / %d\n', nRe, nPend);

lg('\n收尾后处理结束 %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS'));
fclose(fid);
fprintf('POSTPROCESS_DONE  过期图重出 %d/%d\n', nRe, nPend);

% ---------------------------------------------------------------- 局部函数
function tf = is_stale(fig_dir)
%IS_STALE  目录内存在 PNG 且其时间戳早于 data.csv 时为真（与 run_postprocess 同判据）。
d = dir(fullfile(fig_dir, '*.png'));
c = fullfile(fig_dir, 'data.csv');
if isempty(d) || exist(c, 'file') ~= 2
    tf = true;  return
end
tf = any([d.datenum] < dir(c).datenum);
end

function ok = safe_run(fpath, lg)
% 在独立函数工作区里 run，使被调脚本开头的 clear 不影响调用者。
try
    run(fpath);
    ok = true;
catch ME
    ok = false;
    fprintf(2, '[safe_run 失败] %s\n', ME.message);
end
end
