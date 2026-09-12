function tab = func_write_q2(res, prm, tpl_path, out_path)
%FUNC_WRITE_Q2  写出 result2.xlsx（三张表），并回带论文表1/表2/表3 的数值
%
%   表"计划购电量"：日期 × 144 槽的计划购电量 + 全天购电量 + 全天购电费
%   表"充放电量"  ：每日 6 个 4 小时时段的充放电量 + 每日 0:00 / 24:00 储电量
%   表"紧急购电量"：每日紧急购电的时段与电量（无紧急购电的日期填"无"）
%
%   模板的"充放电量""紧急购电量"两张表在附件5 中只给了少量样例（含省略行），
%   故按模板表头标签重建全量行；"计划购电量"表模板已含全部 334 行日期，按格填充。
%   "紧急购电量"表模板每天预留 3 行，本数据单日最多 8 段，故按实际段数占行（避免截断）。
%
%   输入  res      D×T 逐日矩阵（buy_m / em_m / chg_m / dis_m / Eend_m 等）
%         prm      参数结构体
%         tpl_path 附件5 的 result2.xlsx 模板路径
%         out_path 输出路径
%   输出  tab      论文表1/表2/表3 的数值

D  = numel(res.rep_idx);
T  = prm.T;
dt = prm.dt;
ri = res.rep_idx;                       % 报送窗口内的日索引（2025-02-01 起）

% 全天口径：购电量取计划（正常）购电量；购电费 = 正常购电费 + 紧急购电费
day_buy  = sum(res.buy_m(ri,:), 2);
day_cost = sum(res.price_v(:).' .* res.buy_m(ri,:), 2) ...
         + prm.kappa_em * sum(res.price_v(:).' .* res.em_m(ri,:), 2);

if exist(out_path, 'file'); delete(out_path); end

% ---- 表 1：计划购电量 ----
sh1 = blank_missing(readcell(tpl_path, 'Sheet', '计划购电量', 'Range', 'A1:EQ335'));
sh1(2:1+D, 2:1+T) = num2cell(res.buy_m(ri,:));
sh1(2:1+D, 2+T)   = num2cell(day_buy);
sh1(2:1+D, 3+T)   = num2cell(day_cost);
writecell(sh1, out_path, 'Sheet', '计划购电量');

% ---- 表 2：充放电量 ----
blk  = 24;                              % 每段 24 槽
nB   = T / blk;
hdr2 = readcell(tpl_path, 'Sheet', '充放电量', 'Range', 'A1:F1');
lab2 = readcell(tpl_path, 'Sheet', '充放电量', 'Range', 'B2:B7');     % 6 个时段标签
sh2 = cell(1 + D*nB, 6);
sh2(1,:) = hdr2;
chg_blk = zeros(D, nB);  dis_blk = zeros(D, nB);
for b = 1:nB
    sl = (b-1)*blk + (1:blk);
    chg_blk(:,b) = sum(res.chg_m(ri, sl), 2);
    dis_blk(:,b) = sum(res.dis_m(ri, sl), 2);
end
for d = 1:D
    r0 = 1 + (d-1)*nB;
    for b = 1:nB
        sh2{r0+b, 2} = lab2{b};
        sh2{r0+b, 3} = chg_blk(d,b);
        sh2{r0+b, 4} = dis_blk(d,b);
    end
    sh2{r0+1, 1} = res.day_list(ri(d));          % 日期只写在每日首行
    sh2{r0+1, 5} = '0:00';                       % 时刻列按模板写法，储电量记在 F 列
    sh2{r0+2, 5} = '24:00';
    sh2{r0+1, 6} = res.E0_m(ri(d));              % 0:00 储电量
    sh2{r0+2, 6} = res.Eend_m(ri(d), T);         % 24:00 储电量
end
writecell(sh2, out_path, 'Sheet', '充放电量');

% ---- 表 3：紧急购电量 ----
% 模板对每天预留 3 行，但本数据单日最多 8 段（85 天超过 3 段），固定 3 行会截断结果；
% 故按「每日实际段数占行、日期与段数标在每日首行」排布，0 段的日期占一行并填“无”。
hdr3 = readcell(tpl_path, 'Sheet', '紧急购电量', 'Range', 'A1:C1');
wins = cell(D,1);  kwins = cell(D,1);  nrow3 = zeros(D,1);
for d = 1:D
    [wins{d}, kwins{d}] = em_windows(res.em_m(ri(d),:));
    nrow3(d) = max(1, numel(wins{d}));
end
sh3 = cell(1 + sum(nrow3), 3);
sh3(1,:) = hdr3;
tab.t3_date = cell(D,1);  tab.t3_win = cell(D,1);  tab.t3_kwh = zeros(D,1);
r = 1;
for d = 1:D
    k = ri(d);
    sh3{r+1, 1} = res.day_list(k);               % 日期只写在每日首行
    if isempty(wins{d})
        sh3{r+1, 2} = '无';  sh3{r+1, 3} = 0;
    else
        for j = 1:numel(wins{d})
            sh3{r+j, 2} = wins{d}{j};  sh3{r+j, 3} = kwins{d}(j);
        end
    end
    r = r + nrow3(d);
    tab.t3_date{d} = char(res.day_list(k), 'yyyy-MM-dd');
    tab.t3_win{d}  = strjoin(wins{d}, '、');
    tab.t3_kwh(d)  = sum(res.em_m(k,:));
end
writecell(sh3, out_path, 'Sheet', '紧急购电量');

% ---- 论文表1 / 表2：指定日期 ----
hours = [10 12 14 16 18 20];
slots = hours * 6 + 1;                                       % 时段 [h:00, h:10) 对应槽
key_date = [datetime(2025,3,20); datetime(2025,6,21); datetime(2025,9,23); datetime(2025,12,21)];
nK = numel(key_date);
tab.t1_slot  = slots(:);
tab.t1_label = arrayfun(@(h) sprintf('%d:00-%d:10', h, h), hours, 'UniformOutput', false).';
tab.t1_buy   = zeros(nK, numel(slots));
tab.t1_total = zeros(nK,1);   tab.t1_cost = zeros(nK,1);
tab.t2_chg   = zeros(nK, nB); tab.t2_dis = zeros(nK, nB);
tab.t2_E0    = zeros(nK,1);   tab.t2_ET  = zeros(nK,1);
tab.t2_label = lab2;
tab.date_str = cell(nK,1);
for k = 1:nK
    d = find(res.day_list == key_date(k), 1);
    assert(~isempty(d), '指定日期 %s 不在数据范围内', char(key_date(k)));
    tab.date_str{k} = char(key_date(k), 'yyyy-MM-dd');
    tab.t1_buy(k,:) = res.buy_m(d, slots);
    tab.t1_total(k) = sum(res.buy_m(d,:));
    tab.t1_cost(k)  = sum(res.price_v(:).' .* res.buy_m(d,:)) ...
                    + prm.kappa_em * sum(res.price_v(:).' .* res.em_m(d,:));
    tab.t2_chg(k,:) = sum(reshape(res.chg_m(d,:), blk, nB)).';
    tab.t2_dis(k,:) = sum(reshape(res.dis_m(d,:), blk, nB)).';
    tab.t2_E0(k)    = res.E0_m(d);
    tab.t2_ET(k)    = res.Eend_m(d, T);
end
tab.dt = dt;
tab.nB = nB;

end

% ---------------------------------------------------------------- 局部函数
function [w, kw] = em_windows(em_row)
% 提取该日紧急购电的连续时段区间及各区间的购电量（kWh）
k = find(em_row > 1e-6);
k = k(:);
if isempty(k); w = {}; kw = []; return; end
brk = [0; find(diff(k) > 1); numel(k)];
n = numel(brk) - 1;
w = cell(n, 1);  kw = zeros(n, 1);
for j = 1:n
    idx   = k(brk(j)+1 : brk(j+1));
    w{j}  = sprintf('%s-%s', slot_time(idx(1) - 1), slot_time(idx(end)));
    kw(j) = sum(em_row(idx));
end
end

function s = slot_time(k)
% 第 k 个时刻标签（k 槽 = 10 分钟；k=0 得 0:00，k=144 得 24:00）
m = k * 10;
s = sprintf('%d:%02d', floor(m/60), mod(m,60));
end

function C = blank_missing(C)
% 把 readcell 读到的空单元（missing）替换为空字符，便于 writecell 写出
for k = 1:numel(C)
    if ismissing(C{k})
        C{k} = '';
    end
end
end
