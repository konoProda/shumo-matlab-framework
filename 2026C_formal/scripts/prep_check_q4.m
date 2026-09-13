% prep_check_q4.m —— Q4 轮数据校验（附件4 电价 + 附件5 模板）
%
%   问题四的全部结论压在附件4 上，故本轮校验重点：
%     ① 附件4 的完整性、数值合法性（readcell 逐格判型，不只看空值）、是否含负价；
%     ② 附件4 的时间列口径是否与附件2/附件1 同源（表头逐列比对）；
%     ③ 价格的可预测性画像：星期结构、同星期回溯的精度、以及两个朴素基准的对照；
%     ④ 峰谷时刻误差（储能调度关心的不是平均误差，而是"何时贵、何时便宜"）；
%     ⑤ 两张结果模板与问题二/三模板是否同构。
%
%   用法：matlab -batch "run('scripts/prep_check_q4.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
OUT = fullfile(PROJ_ROOT, 'outputs');
fid = fopen(fullfile(OUT, '测试记录', 'preprocess_log_q4.txt'), 'w', 'n', 'UTF-8');
if fid < 0; error('无法写日志'); end
lg = @(varargin) fprintf(fid, varargin{:});
say = @(varargin) fprintf(varargin{:});

lg('Q4 轮数据校验日志（附件4 电价 + 附件5 模板）\n');
lg('生成：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
lg('%s\n\n', repmat('=', 1, 72));

%% ---------- 附件1/2 基线 ----------
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D = numel(day_list);  T = 144;
raw1 = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
pr_raw = cell2mat(raw1(2:145, 2));  pr1 = pr_raw([T, 1:T-1]);      % 与 func_read_q2 同一右移口径

lg('【附件1 典型日电价（作为冷启动回退曲线）】\n');
lg('  144 值：最小 %.4f  最大 %.4f  均值 %.4f 元/kWh\n', min(pr1), max(pr1), mean(pr1));

%% ---------- 附件4 ----------
lg('\n【附件4 实时电价】\n');
raw4 = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件4.xlsx'), 'Sheet', 'Sheet1');
lg('  尺寸 %d 行 × %d 列；表头第 1 列为日期、其余 %d 列为时段\n', ...
   size(raw4, 1), size(raw4, 2), size(raw4, 2) - 1);

body = raw4(2:end, 2:end);
isn = ~cellfun(@isnumeric, body);
lg('  ★ 非数值文本扫描（readcell 逐格判型）：%d 个\n', nnz(isn));
if any(isn(:))
    u = unique(cellfun(@(v) char(string(v)), body(isn), 'UniformOutput', false));
    lg('      出现过的非数值写法：%s\n', strjoin(unique(u).', ', '));
end
Pr = cell2mat(body);                                   % 365×144
lg('  原始块：最小 %.4f  最大 %.4f  均值 %.4f  负值 %d 个  零值 %d 个\n', ...
   min(Pr(:)), max(Pr(:)), mean(Pr(:)), nnz(Pr < 0), nnz(Pr == 0));

% 与附件2 同款的日周期右移一位
price_m = [[Pr(1,T); Pr(1:D-1,T)], Pr(:, 1:T-1)];
assert(all(isfinite(price_m(:))) && size(price_m,1) == D && size(price_m,2) == T, ...
       '附件4 维度或数值异常');
lg('  右移一位后（与附件2 同一口径）：最小 %.4f  最大 %.4f  均值 %.4f  负值 %d 个\n', ...
   min(price_m(:)), max(price_m(:)), mean(price_m(:)), nnz(price_m < 0));
lg('  ★ 负电价判定：全年 **%d** 个负值、%d 个零值 ⇒ 建模文档 §10「不默认截断为非负」\n', ...
   nnz(price_m < 0), nnz(price_m == 0));
lg('    在本数据上不产生数值差异；实现上仍**不**对情景价格做 max(0,·) 裁剪。\n');

% 表头同源性
h2 = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件2.xlsx'), 'Sheet', '光伏发电实际功率');
h2 = h2(1, 2:end);  h4 = raw4(1, 2:end);
same = numel(h2) == numel(h4) && all(cellfun(@(a, b) strcmp(char(string(a)), char(string(b))), h2, h4));
lg('  时间列同源性：附件2 与附件4 表头逐列相同 ⇒ %s\n', ternary(same, '是（同口径，同款右移）', '否（需重新核定）'));

% 与附件1 的量级关系
lg('  与附件1 固定电价的均值比：%.4f（%.4f / %.4f）\n', ...
   mean(price_m(:))/mean(pr1), mean(price_m(:)), mean(pr1));

%% ---------- 星期结构 ----------
lg('\n【价格的可预测性画像】\n');
wd = weekday(day_list);                                % 1=周日
nm = {'日', '一', '二', '三', '四', '五', '六'};
lg('  按星期的日均价（元/kWh）：\n     ');
for k = 1:7
    m = wd == k;
    lg('%s %.4f    ', nm{k}, mean(mean(price_m(m, :), 2)));
end
lg('\n');
dm = mean(price_m, 2);
lg('  日间价差：日均价最小 %.4f 最大 %.4f；单日峰谷差均值 %.4f（最小 %.4f 最大 %.4f）\n', ...
   min(dm), max(dm), mean(max(price_m, [], 2) - min(price_m, [], 2)), ...
   min(max(price_m, [], 2) - min(price_m, [], 2)), max(max(price_m, [], 2) - min(price_m, [], 2)));

%% ---------- 同星期回溯预测与基准对照 ----------
Kfc = 4;
[Phat, ~, fbf] = func_forecast_q4(price_m, pr1, Kfc, []);   % 逐日模式：预测第 d 天（只用 τ<d）
ok  = ~fbf;                                                 % 剔除走冷启动回退的日子
ep  = Phat(ok, :) - price_m(ok, :);
lg('\n  同星期回溯（最近 %d 个同星期日的均值，严格只用历史）\n', Kfc);
lg('    可用 %d/%d 天（其余走冷启动回退，不计入精度）；\n', nnz(ok), D);
lg('    MAE %.4f   RMSE %.4f   偏差 %+.4f 元/kWh   相对 MAE %.2f%%\n', ...
   mean(abs(ep(:))), sqrt(mean(ep(:).^2)), mean(ep(:)), ...
   100*mean(abs(ep(:)))/mean(price_m(ok, :), 'all'));

% 基准一：附件1 典型日电价曲线原样复用
e1 = repmat(pr1(:).', D, 1) - price_m;
lg('  基准甲（附件1 典型日曲线原样复用）：MAE %.4f   RMSE %.4f   偏差 %+.4f\n', ...
   mean(abs(e1(:))), sqrt(mean(e1(:).^2)), mean(e1(:)));
% 基准二：昨日同时刻（persistence）
e2 = price_m(2:end, :) - price_m(1:end-1, :);
lg('  基准乙（昨日同时刻 persistence）：    MAE %.4f   RMSE %.4f\n', ...
   mean(abs(e2(:))), sqrt(mean(e2(:).^2)));

%% ---------- 峰谷时刻误差 ----------
lg('\n  峰谷时刻误差（储能调度真正关心的量）：\n');
pk_t = zeros(D,1);  vl_t = zeros(D,1);
pk_p = zeros(D,1);  vl_p = zeros(D,1);
for d = 1:D
    [~, pk_t(d)] = max(price_m(d, :));    [~, vl_t(d)] = min(price_m(d, :));
    if ok(d)
        [~, pk_p(d)] = max(Phat(d, :));   [~, vl_p(d)] = min(Phat(d, :));
    end
end
dpk = pk_p(ok) - pk_t(ok);   dvl = vl_p(ok) - vl_t(ok);
lg('    峰时刻偏差（槽）：精确命中 %d/%d (%.1f%%)，|偏差|<=6 槽(1h) 占 %.1f%%\n', ...
   nnz(dpk == 0), numel(dpk), 100*nnz(dpk == 0)/numel(dpk), 100*mean(abs(dpk) <= 6));
lg('    谷时刻偏差（槽）：精确命中 %d/%d (%.1f%%)，|偏差|<=6 槽(1h) 占 %.1f%%\n', ...
   nnz(dvl == 0), numel(dvl), 100*nnz(dvl == 0)/numel(dvl), 100*mean(abs(dvl) <= 6));
pv_t = max(price_m, [], 2) - min(price_m, [], 2);
pv_p = max(Phat, [], 2) - min(Phat, [], 2);
lg('    峰谷差预测：MAE %.4f 元/kWh（实际均值 %.4f）\n', ...
   mean(abs(pv_p(ok) - pv_t(ok))), mean(pv_t));

%% ---------- 附件5 模板 ----------
lg('\n【附件5 结果模板】\n');
rd = @(p) fread(fopen(p, 'r'), Inf, '*uint8');
pairA = {'result2.xlsx', 'result3.xlsx'};              % 已被验证过的现成模板
pairB = {'result4-2.xlsx', 'result4-3.xlsx'};          % 题目另给的问题四模板
for k = 1:2
    a = fullfile(PROJ_ROOT, 'data', '附件', '附件5', pairA{k});
    b = fullfile(PROJ_ROOT, 'data', '附件', '附件5', pairB{k});
    sa = rd(a);  sb = rd(b);
    samef = numel(sa) == numel(sb) && isequal(sa, sb);
    lg('  %s 与 %s：%s\n', pairA{k}, pairB{k}, ...
       ternary(samef, '二进制完全相同 ⇒ 字段口径可原样复用', '不同 ⇒ 需逐字段核对'));
    lg('     表：%s\n', strjoin(sheetnames(b), ' / '));
end

lg('\n%s\n', repmat('=', 1, 72));
lg('校验完成。\n');
fclose(fid);
say('PREP_CHECK_Q4_DONE\n');

function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
