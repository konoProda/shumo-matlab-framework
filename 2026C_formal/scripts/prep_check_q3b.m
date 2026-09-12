% prep_check_q3b.m —— Q3b 轮数据校验（附件1/2/3/5）
%
%   正式建模改用附件3 作为近端 24 h 光伏中心预报，故本次校验的重点是：
%     ① 附件3 的完整性（365 天 × 4 个发布时刻 × 24 小时）；
%     ② 数值列的非数值文本扫描（readcell 逐格判型，不只看空值）；
%     ③ "预报k小时"索引口径的**独立复核**（夜间全零 / 日出跃变配对 /
%        与附件2 实际光伏的逐阶段相关性与偏差画像）——口径错一小时时相关性会明显掉。
%
%   用法：matlab -batch "run('scripts/prep_check_q3b.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
OUT = fullfile(PROJ_ROOT, 'outputs');
fid = fopen(fullfile(OUT, 'preprocess_log_q3b.txt'), 'w', 'n', 'UTF-8');
if fid < 0; error('无法写日志'); end
lg = @(varargin) fprintf(fid, varargin{:});
say = @(varargin) fprintf(varargin{:});

lg('Q3b 轮数据校验日志（附件1/2/3/5）\n');
lg('生成：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
lg('%s\n\n', repmat('=', 1, 72));

%% ---------- 附件1：电价 ----------
raw1 = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
lg('【附件1 电价 / 典型日曲线】\n');
lg('  尺寸 %d 行 × %d 列；数据块 = 第 2..145 行的第 2~4 列\n', size(raw1, 1), size(raw1, 2));
pr_v = cell2mat(raw1(2:145, 2));
lg('  电价：n=%d  最小 %.4f  最大 %.4f  均值 %.4f  负值 %d 个\n', ...
   numel(pr_v), min(pr_v), max(pr_v), mean(pr_v), nnz(pr_v < 0));

%% ---------- 附件2：负荷与光伏实际 ----------
lg('\n【附件2 负荷与光伏实际】\n');
sh2 = sheetnames(fullfile(PROJ_ROOT, 'data', '附件', '附件2.xlsx'));
for k = 1:numel(sh2)
    raw2 = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件2.xlsx'), 'Sheet', sh2{k});
    lg('  表"%s"：%d 行 × %d 列\n', sh2{k}, size(raw2, 1), size(raw2, 2));
    body = raw2(2:end, 2:end);
    isn = ~cellfun(@isnumeric, body);
    lg('  ★ 非数值文本扫描（readcell 逐格判型）：%d 个\n', nnz(isn));
    if any(isn(:))
        u = unique(cellfun(@(v) char(string(v)), body(isn), 'UniformOutput', false));
        lg('      出现过的非数值写法：%s\n', strjoin(unique(u).', ', '));
    end
    Mb = cell2mat(body);
    lg('      数值块：最小 %.4f  最大 %.4f  负值 %d 个\n', min(Mb(:)), max(Mb(:)), nnz(Mb < 0));
end

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
lg('  经 func_read_q2 读出：%d 天 × %d 槽；负荷峰值 %.1f kW；光伏峰值 %.1f kW\n', ...
   size(load_m, 1), size(load_m, 2), max(load_m(:)), max(pv_m(:)));

%% ---------- 附件3：光伏预报 ----------
lg('\n【附件3 光伏预报】\n');
raw3 = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件3.xlsx'), 'Sheet', 'Sheet1');
lg('  尺寸 %d 行 × %d 列\n', size(raw3, 1), size(raw3, 2));
D = numel(day_list);
lg('  行数核对：1 + 4×365 = %d；实际 %d ⇒ %s\n', 1 + 4*D, size(raw3, 1), ...
   ternary(size(raw3,1) == 1 + 4*D, '一致', '不一致'));

% 数值块非数值扫描
blk3 = raw3(2:end, 3:end);
isn3 = ~cellfun(@isnumeric, blk3);
lg('  ★ 数值块非数值文本扫描：%d 个\n', nnz(isn3));
if any(isn3(:))
    u = unique(cellfun(@(v) char(string(v)), blk3(isn3), 'UniformOutput', false));
    lg('      出现过的非数值写法：%s\n', strjoin(unique(u).', ', '));
end
F3 = cell2mat(blk3);                       % 1460×24
lg('  数值块：最小 %.4f  最大 %.4f  负值 %d 个\n', min(F3(:)), max(F3(:)), nnz(F3 < 0));

% 发布时刻标签核对
tlab = raw3(2:end, 2);
lg('  发布时刻标签：%s\n', strjoin(unique(cellfun(@(v) char(string(v)), tlab, ...
    'UniformOutput', false)).', ' / '));

% 组装为 D×4×24
fc3 = zeros(D, 4, 24);
for j = 1:4
    blk = raw3(2 + (0:D-1)*4 + (j-1), 3:26);
    fc3(:, j, :) = reshape(cell2mat(blk), [D 1 24]);
end
lg('  组装后：%d 天 × %d 个发布时刻 × %d 小时，有限值 %d/%d\n', ...
   D, 4, 24, nnz(isfinite(fc3)), numel(fc3));

%% ---------- 附件3 索引口径独立复核 ----------
lg('\n【附件3 索引口径独立复核】\n');
lg('  口径：发布时刻 τ 的"预报第 k 小时" ↔ 区间 [τ+(k−1)h, τ+kh)\n');

% 判据一：夜间全零。0:00 发布的 k=1..6（即 0:00—6:00）应恒为 0
night_blk = fc3(:, 1, 1:6);
lg('  判据一（0:00 发布 k=1..6 = 0:00—6:00 恒为夜）：最大 %.4f kW\n', max(night_blk(:)));
% 18:00 发布的 k=1..3（18:00—21:00）
night_blk2 = fc3(:, 4, 1:3);
lg('  判据一（18:00 发布 k=1..3 = 18:00—21:00 恒为夜）：最大 %.4f kW\n', max(night_blk2(:)));

% 判据二：逐阶段把整点预报线性插值成 10 min，与附件2 实际光伏对齐，
%         若索引整体错位一小时，相关系数会明显下降
hidx = floor((0:143)/6) + 1;
for j = 1:4
    s0 = (j-1)*6;                          % 发布时刻（小时）
    ns = 144 - s0;                         % 该阶段覆盖的槽数（当天剩余 + 次日同刻）
    Fc = zeros(D, ns);  Ac = zeros(D, ns);
    for d = 1:D
        f24 = squeeze(fc3(d, j, :)).';     % 1×24
        tt = 0:ns-1;
        h = floor(tt/6);  m = mod(tt, 6);
        p_lo = f24(h + 1);
        p_hi = f24(min(h + 2, 24));        % 末位平延，不外推
        Fc(d, :) = p_lo + (m/6).*(p_hi - p_lo);
        % 实际光伏：跨日取（发布后 ns 个 10 min 槽）
        g0 = (d-1)*144 + s0;               % 全局 0 基槽号
        gi = g0 + (1:ns);
        gi = min(gi, D*144);
        Ac(d, :) = pv_m(gi);
    end
    c = pcorr(Fc(:), Ac(:));
    lg('  判据二 s=%2d:00 发布：插值预报 vs 实际光伏  相关 %.4f  MAE %8.2f kW  偏差 %+8.2f kW\n', ...
       s0, c, mean(abs(Fc(:)-Ac(:))), mean(Fc(:)-Ac(:)));
end

% 判据二对照：错位一小时
lg('  判据二对照（人为把预报整体错位 +1 小时，相关性应下降）：\n');
for j = 1:4
    s0 = (j-1)*6;  ns = 144 - s0;
    Fc = zeros(D, ns);  Ac = zeros(D, ns);
    for d = 1:D
        f24 = squeeze(fc3(d, j, :)).';
        tt = 0:ns-1;
        h = floor(tt/6);  m = mod(tt, 6);
        p_lo = f24(h + 1);
        p_hi = f24(min(h + 2, 24));
        Fc(d, :) = p_lo + (m/6).*(p_hi - p_lo);
        g0 = (d-1)*144 + s0;  gi = min(g0 + (1:ns) + 6, D*144);
        Ac(d, :) = pv_m(gi);
    end
    lg('      s=%2d:00 错位后相关 %.4f\n', s0, pcorr(Fc(:), Ac(:)));
end

% 判据三：按提前量分档看误差（提前量越大应越差）
lg('  判据三 误差随提前量分档（s=0:00 发布，按小时档）：\n');
f24all = squeeze(fc3(:, 1, :));            % D×24
e = zeros(D, 24);
for k = 1:24
    gi = (0:D-1)*144 + (k-1)*6 + 3;        % 该小时中点槽
    e(:, k) = mean(pv_m(gi), 2) - f24all(:, k);
end
lg('      提前量 1-6h   MAE %8.2f  偏差 %+8.2f kWh/kW\n', mean(abs(e(:, 1:6)), 'all'), mean(e(:, 1:6), 'all'));
lg('      提前量 7-12h  MAE %8.2f  偏差 %+8.2f\n', mean(abs(e(:, 7:12)), 'all'), mean(e(:, 7:12), 'all'));
lg('      提前量 13-18h MAE %8.2f  偏差 %+8.2f\n', mean(abs(e(:, 13:18)), 'all'), mean(e(:, 13:18), 'all'));
lg('      提前量 19-24h MAE %8.2f  偏差 %+8.2f\n', mean(abs(e(:, 19:24)), 'all'), mean(e(:, 19:24), 'all'));

%% ---------- 附件5 模板 ----------
lg('\n【附件5 result3.xlsx 模板】\n');
sn = sheetnames(fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result3.xlsx'));
for k = 1:numel(sn)
    c = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result3.xlsx'), 'Sheet', sn{k});
    lg('  表"%s"：%d 行 × %d 列；首行：%s\n', sn{k}, size(c, 1), size(c, 2), ...
       strjoin(cellfun(@(v) char(string(v)), c(1, 1:min(6, size(c, 2))), 'UniformOutput', false), ' | '));
end

lg('\n%s\n', repmat('=', 1, 72));
lg('校验完成。\n');
fclose(fid);
say('PREP_CHECK_Q3B_DONE\n');

function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end

function r = pcorr(u, v)
% 皮尔逊相关（自算，不依赖统计工具箱）
u = u(:) - mean(u);  v = v(:) - mean(v);
r = (u.' * v) / sqrt((u.' * u) * (v.' * v));
end
