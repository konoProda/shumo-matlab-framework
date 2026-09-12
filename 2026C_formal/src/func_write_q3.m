function tab = func_write_q3(res, prm, tpl_path, out_path)
%FUNC_WRITE_Q3  写出 result3.xlsx（四张表），并回带论文表1/表2/表3 的数值
%
%   表"计划购电量"：0:00 制定的原始计划购电量（逐槽）+ 全天购电量 + 全天购电费
%   表"调整购电量"：四阶段拼接后的最终生效购电量 + 全天购电量 + 全天购电费
%                   （两张表版式相同；"全天购电费"均填当日三项费用合计）
%   表"充放电量"  ：每日 6 个 4 小时时段的充放电量 + 每日 0:00 / 24:00 储电量
%   表"紧急购电量"：每日紧急购电的时段与电量（无紧急购电的日期填"无"）
%
%   模板的"充放电量""紧急购电量"两张表只给了少量样例（含省略行），故按模板表头标签
%   重建全量行；两张购电量表模板已含全部 334 行日期，按格填充。
%
%   输入  res      func_roll_q3 的输出结构
%         prm      参数结构体
%         tpl_path 附件5 的 result3.xlsx 模板路径
%         out_path 输出路径
%   输出  tab      论文表1/表2/表3 的数值（购电量口径 = 最终生效购电量）

D  = numel(res.E0_m);
T  = prm.T;
dt = prm.dt;

% 结果窗口：2025-02-01 起（与问题二、模板一致）；小切片自检时无该日期，则整段报出
if isfield(res, 'rep_idx') && ~isempty(res.rep_idx)
    ri = res.rep_idx;
else
    ri = find(res.day_list >= datetime(2025,2,1));
    if isempty(ri); ri = (1:D).'; end
end
D  = numel(ri);

day_cost = res.cost(ri).';

if exist(out_path, 'file'); delete(out_path); end

% ---- 表 1：计划购电量 ----
sh1 = blank_missing(readcell(tpl_path, 'Sheet', '计划购电量', 'Range', 'A1:EQ335'));
sh1(2:1+D, 2:1+T) = num2cell(res.plan_m(ri,:));
sh1(2:1+D, 2+T)   = num2cell(sum(res.plan_m(ri,:), 2));
sh1(2:1+D, 3+T)   = num2cell(day_cost);
writecell(sh1, out_path, 'Sheet', '计划购电量');

% ---- 表 2：调整购电量（最终生效） ----
shA = blank_missing(readcell(tpl_path, 'Sheet', '调整购电量', 'Range', 'A1:EQ335'));
shA(2:1+D, 2:1+T) = num2cell(res.adj_m(ri,:));
shA(2:1+D, 2+T)   = num2cell(sum(res.adj_m(ri,:), 2));
shA(2:1+D, 3+T)   = num2cell(day_cost);
writecell(shA, out_path, 'Sheet', '调整购电量');

% ---- 表 3：充放电量 ----
blk  = 24;
nB   = T / blk;
hdr2 = readcell(tpl_path, 'Sheet', '充放电量', 'Range', 'A1:F1');
lab2 = readcell(tpl_path, 'Sheet', '充放电量', 'Range', 'B2:B7');
sh2 = cell(1 + D*nB, 6);
sh2(1,:) = hdr2;
for d = 1:D
    r0 = 1 + (d-1)*nB;
    for b = 1:nB
        sl = (b-1)*blk + (1:blk);
        sh2{r0+b, 2} = lab2{b};
        sh2{r0+b, 3} = sum(res.chg_m(ri(d), sl));
        sh2{r0+b, 4} = sum(res.dis_m(ri(d), sl));
    end
    sh2{r0+1, 1} = res.day_list(ri(d));
    sh2{r0+1, 5} = '0:00';
    sh2{r0+2, 5} = '24:00';
    sh2{r0+1, 6} = res.E0_m(ri(d));
    sh2{r0+2, 6} = res.Eend_m(ri(d), T);
end
writecell(sh2, out_path, 'Sheet', '充放电量');

% ---- 表 4：紧急购电量 ----
% 模板对每天预留 3 行，但本数据单日段数可超过 3，故按实际段数占行，日期标在每日首行。
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
    sh3{r+1, 1} = res.day_list(k);
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
slots = hours * 6 + 1;
key_date = [datetime(2025,3,20); datetime(2025,6,21); datetime(2025,9,23); datetime(2025,12,21)];
nK = numel(key_date);
tab.t1_slot  = slots(:);
tab.t1_label = arrayfun(@(h) sprintf('%d:00-%d:10', h, h), hours, 'UniformOutput', false).';
tab.t1_buy   = nan(nK, numel(slots));          % 最终生效购电量
tab.t1_plan  = nan(nK, numel(slots));          % 0:00 原计划
tab.t1_total = nan(nK,1);   tab.t1_cost = nan(nK,1);
tab.t2_chg   = nan(nK, nB); tab.t2_dis = nan(nK, nB);
tab.t2_E0    = nan(nK,1);   tab.t2_ET  = nan(nK,1);
tab.t2_label = lab2;
tab.cost_plan = nan(nK,1);  tab.cost_adj = nan(nK,1);  tab.cost_em = nan(nK,1);
tab.em_window = cell(nK,1);   tab.date_str = cell(nK,1);
for k = 1:nK
    d = find(res.day_list == key_date(k), 1);
    if isempty(d)
        tab.date_str{k} = char(key_date(k), 'yyyy-MM-dd');   % 不在本段数据内（小切片自检用）
        continue;
    end
    tab.date_str{k} = char(key_date(k), 'yyyy-MM-dd');
    tab.t1_buy(k,:)  = res.adj_m(d, slots);
    tab.t1_plan(k,:) = res.plan_m(d, slots);
    tab.t1_total(k)  = sum(res.adj_m(d,:));
    tab.t1_cost(k)   = res.cost(d);
    tab.t2_chg(k,:)  = sum(reshape(res.chg_m(d,:), blk, nB)).';
    tab.t2_dis(k,:)  = sum(reshape(res.dis_m(d,:), blk, nB)).';
    tab.t2_E0(k)     = res.E0_m(d);
    tab.t2_ET(k)     = res.Eend_m(d, T);
    tab.cost_plan(k) = res.cost_plan(d);
    tab.cost_adj(k)  = res.cost_adj(d);
    tab.cost_em(k)   = res.cost_em(d);
    tab.em_window{k} = strjoin(wins{find(ri == d, 1)}, '、');
end
tab.dt = dt;
tab.nB = nB;

end

% ---------------------------------------------------------------- 局部函数
function [w, kw] = em_windows(em_row)
% 该日紧急购电的连续时段区间及各区间电量（kWh）
k = find(em_row > 1e-6);
k = k(:);
if isempty(k); w = {}; kw = []; return; end
brk = [0; find(diff(k) > 1); numel(k)];
n = numel(brk) - 1;
w = cell(n, 1);  kw = zeros(n, 1);
for j = 1:n
    idx  = k(brk(j)+1 : brk(j+1));
    w{j} = sprintf('%s-%s', slot_time(idx(1) - 1), slot_time(idx(end)));
    kw(j) = sum(em_row(idx));
end
end

function s = slot_time(k)
% 第 k 个时刻标签（k 槽 = 10 分钟；k=0 得 0:00，k=144 得 24:00）
m = k * 10;
s = sprintf('%d:%02d', floor(m/60), mod(m,60));
end

function C = blank_missing(C)
for k = 1:numel(C)
    if ismissing(C{k})
        C{k} = '';
    end
end
end
