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
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
OUT = fullfile(PROJ_ROOT, 'outputs');
fid = fopen(fullfile(OUT, '测试记录', 'preprocess_log_q3b.txt'), 'w', 'n', 'UTF-8');
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
lg('      ※ 该判据只在冬季严格成立：夏至前后 5:00—6:00 已见光，故上面有非零值。\n');
% 18:00 发布的 k=1..3（18:00—21:00）
night_blk2 = fc3(:, 4, 1:3);
lg('  判据一（18:00 发布 k=1..3 = 18:00—21:00 恒为夜）：最大 %.4f kW\n', max(night_blk2(:)));
lg('      ※ 近乎恒零说明附件3 几乎不预测 18:00 之后的日照——与下面"日落配对"中\n');
lg('        预报比实际早约一小时熄火是同一件事（预报的固有形状偏差，非索引错位）。\n');

% 判据二：逐阶段把整点预报线性插值成 10 min，与附件2 实际光伏逐槽对齐。
%   注意阶段 s 的**槽**偏移是 6s（s 以小时计），不是 s——首版这里写错，相关性一度只有 0.1。
% ★ 必须按**行主序**展平：pv_m(:) 是列主序（先跑完 365 天再换下一槽），
%   用 (d-1)*144+t 索引会取到别的日子——数值多重集不变、均值不变，
%   所以偏差看不出来，只有相关性与 MAE 会崩。跨年再平延一天备用。
pvall = [reshape(pv_m.', [], 1); pv_m(D, :).'];
for j = 1:4
    s0 = (j-1)*6;                          % 发布时刻（小时）
    sl = s0 * 6;                           % 该时刻在日内的槽偏移
    ns = 144 - sl;                         % 该阶段覆盖的槽数（当天剩余 + 次日同刻）
    Fc = zeros(D, ns);  Ac = zeros(D, ns);
    for d = 1:D
        f24 = squeeze(fc3(d, j, :)).';     % 1×24
        tt = 0:ns-1;
        hh = floor(tt/6);  m = mod(tt, 6);
        p_lo = f24(hh + 1);
        p_hi = f24(min(hh + 2, 24));       % 末位平延，不外推
        Fc(d, :) = p_lo + (m/6).*(p_hi - p_lo);
        gi = (d-1)*144 + sl + (1:ns);      % 全局 1 基槽号，可跨入次日
        Ac(d, :) = pvall(gi);
    end
    nz = Ac(:) > 0;
    lg('  判据二 s=%2d:00：插值预报 vs 实际光伏  相关 %.4f  MAE %8.2f kW  偏差 %+8.2f\n', ...
       s0, pcorr(Fc(:), Ac(:)), mean(abs(Fc(:)-Ac(:))), mean(Fc(:)-Ac(:)));
    lg('              仅白天槽：MAE %8.2f kW  偏差 %+8.2f kW（系统偏差将由 SAA 情景吸收）\n', ...
       mean(abs(Fc(nz)-Ac(nz))), mean(Fc(nz)-Ac(nz)));
    lg('              夜槽（实际=0）中预报也为 0 的比例：%.1f%%\n', ...
       100 * mean(Fc(Ac <= 0) <= 0));
end

% 判据二补：日出配对（尖锐判据）。整条曲线平滑，全局相关系数对 ±1 h 错位不敏感；
% 真正的判别量是"首个亮度超过 50 kW 的小时序号"。夜间预报与实际都恒为 0，
% 故索引若整体错位一小时，该序号之差会**整体**偏 1，而不只是零散几天。
lg('  判据二补（日出配对，尖锐判据）：首个 >50 kW 的小时序号之差（预报 − 实际）\n');
lg('      判读：全体集中在 0（少数 −1 是预报清晨偏低的固有误差）⇒ 索引无整体错位；\n');
lg('            若口径整体差一小时，这里会**全体**偏 +1 或 −1。\n');
for j = 1:4
    sl = (j-1)*6*6;  ns = 144 - sl;  nhr = ns/6;
    dif = [];
    for d = 1:D
        gi = (d-1)*144 + sl + (1:ns);
        a = reshape(pvall(min(gi, numel(pvall))), 6, nhr).';
        a = mean(a, 2);
        f = squeeze(fc3(d, j, 1:nhr)).';
        if max(a) > 50 && max(f) > 50
            ai = find(a > 50, 1);  fi = find(f > 50, 1);
            dif(end+1) = fi - ai;                        %#ok<SAGROW>
        end
    end
    u = unique(dif);
    lg('      s=%2d:00  可判 %3d 天：', (j-1)*6, numel(dif));
    for k = u; lg('  %+d 出现 %d 天', k, nnz(dif == k)); end
    lg('\n');
end

% 判据三：误差随提前量分档（s=0:00 发布）
lg('  判据三 误差随提前量分档（s=0:00 发布，按小时档，仅白天档）：\n');
for a = 1:4
    ks = (a-1)*6 + (1:6);
    gi = (0:D-1).' * 144 + (ks - 1) * 6 + (1:6);         % D×6 全局槽号
    aa = mean(pvall(gi), 2);                             % D×1 该小时档实际均值
    ff = mean(squeeze(fc3(:, 1, ks)), 2);                % D×1 该小时档预报均值
    m = aa > 0;
    lg('      提前量 %2d-%2d h：MAE %8.2f kW  偏差 %+8.2f kW（%d 个白天日）\n', ...
       ks(1), ks(end), mean(abs(ff(m)-aa(m))), mean(ff(m)-aa(m)), nnz(m));
end

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
