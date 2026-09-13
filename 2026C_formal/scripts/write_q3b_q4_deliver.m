% write_q3b_q4_deliver.m —— 由 Q3b / Q4 的正式口径结果写出交付件
%
%   产出：outputs/result3.xlsx（问题三，S3 = 四时点全用）
%         outputs/result4-2.xlsx（问题四对应问题二）
%         outputs/result4-3.xlsx（问题四对应问题三，四时点全用）
%   全部按附件5 模板的四张表填写，口径见 decisions_q3b.md §七 / decisions_q4.md §八：
%     计划购电量 = P·Δt；调整购电量 = B·Δt（四阶段拼接后的最终生效值，不是 B−P）
%     充放电量   = 实际执行量 + 当日 0:00 / 24:00 储电量（6 个四小时区间）
%     紧急购电量 = 实际执行量，连续时段合并
%     全天购电费 = 当日最终结算费用（Q3b 用附件1 电价；Q4 用附件4 真实电价）
%
%   列映射（沿用问题二已确认的模板口径）：Excel 第 2..144 列 ↔ 模型第 2..144 槽；
%   末列（0:00-0:10+1）按日周期回绕填本日第 1 槽。
%
%   用法：matlab -batch "run('scripts/write_q3b_q4_deliver.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
OUT  = fullfile(PROJ_ROOT, 'outputs');
TPL3 = fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result3.xlsx');
TPL2 = fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result2.xlsx');
[price_v, ~, ~, day_list] = func_read_q2(PROJ_ROOT);
prm = struct('T',144, 'dt',1/6, 'kappa_em',5);

jobs = { ...
  'result3.xlsx',   TPL3, 'final_results_q3b_S3.mat', price_v,             'S3（四时点全用）'; ...
  'result4-2.xlsx', TPL2, 'final_results_q4_Q4-2.mat', [],                 'Q4-2'; ...
  'result4-3.xlsx', TPL3, 'final_results_q4_Q4-3.mat', [],                 'Q4-3'};

for j = 1:size(jobs,1)
    fout = fullfile(OUT, jobs{j,1});
    fmat = fullfile(OUT, jobs{j,3});
    if exist(fmat, 'file') ~= 2
        fprintf('[跳过] %s：未找到 %s\n', jobs{j,1}, jobs{j,3});
        continue;
    end
    S = load(fmat, 'res');
    res = S.res;
    if isempty(jobs{j,4})
        % Q4 的结算电价 = 附件4 真实电价（逐日不同）
        price_use = read_price_act(PROJ_ROOT, prm.T);
    else
        price_use = jobs{j,4};                      % Q3b 用附件1 固定电价
    end
    write_tables(res, day_list, price_use, prm, jobs{j,2}, fout);
    fprintf('[写出] %s（%s）\n', jobs{j,1}, jobs{j,5});
end
fprintf('WRITE_DELIVER_DONE\n');

% ================================================================= 局部函数
function price_act = read_price_act(PROJ_ROOT, T)
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件4.xlsx'), 'Sheet', 'Sheet1');
Pr = cell2mat(raw(2:end, 2:end));
D = size(Pr, 1);
price_act = [[Pr(1,T); Pr(1:D-1,T)], Pr(:, 1:T-1)];
end

function write_tables(res, day_list, price_v, prm, tpl, fout)
T = prm.T;  dt = prm.dt;
D = numel(day_list);
ri = res.rep_idx;                       % 报送窗口 2025-02-01 起
nd = numel(ri);
price_w = price_v(:).';                 % 1×T（Q4 传入的是 D×T 时下面按日取）

%% 读模板取表头与日期列
raw_t1 = readcell(tpl, 'Sheet', '计划购电量');
hdr = raw_t1(1, :);
assert(numel(hdr) == T + 3, '模板列数不符（期望 %d）', T + 3);

%% 表1/表2：计划购电量 / 调整购电量
sh1 = repmat({''}, 1 + nd, T + 3);   sh2 = sh1;
for k = 1:nd
    d = ri(k);
    pv_k = pick_price(price_v, d, T);
    Pk = res.P_kw(d, :).' * dt;         % 计划购电量 kWh
    Bk = res.buy_kw(d, :).' * dt;       % 最终生效购电量 kWh
    dP = max(res.buy_kw(d,:).' - res.P_kw(d,:).', 0);
    dM = max(res.P_kw(d,:).' - res.buy_kw(d,:).', 0);
    cost_n = sum(pv_k.'.*res.P_kw(d,:).' + 1.5*pv_k.'.*dP - 0.5*pv_k.'.*dM) * dt;
    cost_e = prm.kappa_em * sum(pv_k.' .* res.em_m(d,:).') * dt;
    sh1{k+1, 1} = datestr(day_list(d), 'yyyy-mm-dd HH:MM:SS');
    sh2{k+1, 1} = datestr(day_list(d), 'yyyy-mm-dd HH:MM:SS');
    % Excel 第 2..144 列 ↔ 模型第 2..144 槽；第 145 列（0:00-0:10+1）回绕填本日第 1 槽
    sh1(k+1, 2:144) = num2cell(Pk(2:144).');
    sh1{k+1, 145}   = Pk(1);
    sh2(k+1, 2:144) = num2cell(Bk(2:144).');
    sh2{k+1, 145}   = Bk(1);
    sh1{k+1, 146} = sum(Pk);            % 全天购电量
    sh1{k+1, 147} = cost_n + cost_e;    % 全天购电费（最终结算）
    sh2{k+1, 146} = sum(Bk);
    sh2{k+1, 147} = cost_n + cost_e;
end
writecell([hdr; sh1(2:end, :)], fout, 'Sheet', '计划购电量');
writecell([hdr; sh2(2:end, :)], fout, 'Sheet', '调整购电量');

%% 表3：充放电量（6 个 4 小时区间 + 当日 0:00 / 24:00 储电量）
sh3 = repmat({''}, 1 + nd*6, 6);
for k = 1:nd
    d = ri(k);
    r0 = 1 + (k-1)*6;
    sh3{r0+1, 1} = datestr(day_list(d), 'yyyy-mm-dd HH:MM:SS');
    for b = 1:6
        cols = (b-1)*24 + (1:24);
        sh3{r0+b, 2} = sprintf('%d:00-%d:00', (b-1)*4, b*4);
        sh3{r0+b, 3} = sum(res.chg_m(d, cols));       % 充电量 kWh
        sh3{r0+b, 4} = sum(res.dis_m(d, cols));       % 放电量 kWh
    end
    sh3{r0+1, 5} = '00:00';
    sh3{r0+1, 6} = res.E0_m(d);
    sh3{r0+2, 5} = '24:00';
    sh3{r0+2, 6} = res.Etr_m(d, end);
end
sh3 = [{'日期','时间段','充电量','放电量','时刻','储电量'}; sh3(2:end, :)];
writecell(sh3, fout, 'Sheet', '充放电量');

%% 表4：紧急购电量（连续时段合并）
sh4 = {};
for k = 1:nd
    d = ri(k);
    em = res.em_m(d, :).';
    sh4{end+1, 1} = datestr(day_list(d), 'yyyy-mm-dd HH:MM:SS');   %#ok<SAGROW>
    idx = find(em > 1e-6);
    if isempty(idx)
        sh4{end+1, 2} = '无';   sh4{end+1, 3} = 0;                 %#ok<SAGROW>
    else
        brk = [0; find(diff(idx) > 1); numel(idx)];
        for s = 1:numel(brk)-1
            seg = idx(brk(s)+1 : brk(s+1));
            sh4{end+1, 2} = sprintf('%s-%s', slot_time(seg(1)-1), slot_time(seg(end)));  %#ok<SAGROW>
            sh4{end+1, 3} = sum(em(seg));                          %#ok<SAGROW>
        end
    end
end
sh4 = [{'日期','购电时间段','购电量'}; sh4];
writecell(sh4, fout, 'Sheet', '紧急购电量');
end

function p = pick_price(price_v, d, T)
if isvector(price_v) && numel(price_v) == T
    p = price_v(:).';                % 固定电价（附件1 为 144×1 列向量）
else
    p = price_v(d, :);               % 逐日电价（附件4 为 D×T）
end
assert(numel(p) == T, '电价维度不符');
end

function s = slot_time(k)
% 槽 k（0 基，表示区间 [k,k+1)×10min）的起点时刻标签
h = floor(k/6);  m = mod(k, 6) * 10;
s = sprintf('%d:%02d', h, m);
end
