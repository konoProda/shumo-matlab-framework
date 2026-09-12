% write_q2c_deliver.m —— 由第二层正式方案（7 日滚动 SAA + B3）结果写出交付件 result2_q2c.xlsx
%
%   口径依据 outputs/decisions_q2c.md（方案文档 §9、§19）：
%     F1  计划购电量 = G^plan·Δt；充放电量 = C^act·Δt / D^act·Δt；紧急购电量 = H^act·Δt
%     F2  不得用 SAA 情景平均值填官方模板 —— 本脚本只取执行层字段，不碰情景层
%     A5  模板日期列按“起始标签”逐列对应，末列按日周期回绕填本日第 1 槽
%   三张表的列映射、4 小时时段汇总、紧急时段合并一律沿用 func_write_q2（与 Q2b 交付件同一套写法），
%   本脚本只负责取数与单位归一，不另立口径。
%
%   单位约定（易错点，务必先核对再改）：func_exec_q2c 里 out.C/out.D/out.H/out.V/out.W 在函数
%   末尾已乘 Δt（见该文件末段 `out.C = C * dt;` 等），是电量 kWh；func_roll_q2c 原样存入
%   res.chg_m / dis_m / em_m / curt_m / waste_m，故这五个字段同样是 kWh，写表时不得再乘 Δt。
%   只有第一阶段计划购电 res.buy_kw 是功率 kW（它直接取 MILP 变量 G^plan），换算成电量才乘 Δt。
%   即：表 1 = buy_kw·Δt，表 2 = chg_m / dis_m，表 3 = em_m。脚本内两条单位自检会把这个错误当场报出来。
%
%   产物：outputs/result2_q2c.xlsx（交付件）；outputs/q2c_指定日期表.md（四个指定日期表 1~表 3 明细）。
%   不覆盖上一轮的 outputs/result2.xlsx。
%
%   用法：matlab -batch "run('scripts/write_q2c_deliver.m')"；换臂只改 run_name。

run_name = 'L2';                 % 正式交付口径 = SAA + B3；其余臂仅供内部对照
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

f_mat = fullfile(PROJ_ROOT, 'outputs', sprintf('final_results_q2c_%s.mat', run_name));
if exist(f_mat, 'file') ~= 2
    error(['未找到 %s。\n' ...
           '六组运行由 main_q2c.m 顺序跑，该文件要等本臂跑完才生成；' ...
           '先看 outputs/log_q2c_run.txt 与 outputs/ckpt_q2c_%s.mat（断点文件在，说明还在推进）。'], ...
          f_mat, run_name);
end
S = load(f_mat);
prm = S.prm;
if ~strcmp(run_name, 'L2')
    warning('本轮正式交付口径为 L2（SAA+B3，裁决 F1/D2）；当前写入的是 %s 的结果。', run_name);
end

[price_v, load_m, ~, day_list] = func_read_q2(PROJ_ROOT);
D  = numel(day_list);
ri = (find(day_list == datetime(2025,2,1)):D).';          % 报送窗口 2025-02-01 ~ 12-31

% ---- 单位归一：三张表统一以 kWh 取数（见文件头“单位”）----
buy_m = S.res.buy_kw * prm.dt;                            % 表 1：G^plan·Δt
em_m  = S.res.em_m;                                       % 表 3：H^act·Δt（已乘过 dt）
chg_m = S.res.chg_m;  dis_m = S.res.dis_m;                % 表 2：C^act·Δt / D^act·Δt（已乘过 dt）

%% 单位自检（两条都是恒等式，量级错 6 倍必然报警）
% A：储能年度递推 E_end − E_init = ηc·ΣC − ΣD/ηd（跨 365 天，只有 C/D 同为 kWh 才闭合）
res_A = (S.res.Eend_m(D, end) - prm.E_init) ...
      - (prm.eta_ch * sum(chg_m(:)) - sum(dis_m(:)) / prm.eta_dis);
fprintf('单位自检A 储能年度递推残差 %.3e kWh（应≈0）\n', res_A);
if abs(res_A) > 1
    warning('储能递推不闭合：先查 chg_m/dis_m 是否被重复乘了 dt（func_exec_q2c 返回值已是 kWh）。');
end
% B：紧急购电的隐含单价 = cost_em / ΣH·Δt，必落在 κ_em×[min π, max π] 内
tot_em = sum(em_m(ri,:), 'all');
if tot_em > 0
    imp = sum(S.res.cost_em(ri)) / tot_em;
    lo = prm.kappa_em * min(price_v);  hi = prm.kappa_em * max(price_v);
    fprintf('单位自检B 紧急购电隐含单价 %.4f 元/kWh（允许 %.4f~%.4f）\n', imp, lo, hi);
    if imp < lo - 1e-9 || imp > hi + 1e-9
        warning('隐含单价越界：若相差约 6 倍，多半是 em_m 被重复乘了 dt。');
    end
end

%% 交付结果表：三张工作表
out_path = fullfile(PROJ_ROOT, 'outputs', 'result2_q2c.xlsx');
resw = struct('buy_m', buy_m, 'em_m', em_m, 'chg_m', chg_m, 'dis_m', dis_m, ...
              'curt_m', S.res.curt_m, 'Eend_m', S.res.Eend_m, 'E0_m', S.res.E0_m, ...
              'price_v', price_v, 'day_list', day_list, 'rep_idx', ri, ...
              'kappa_em', prm.kappa_em);
tab = func_write_q2(resw, prm, ...
    fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result2.xlsx'), out_path);

Z_plan = sum(S.res.cost_plan(ri));  Z_em = sum(S.res.cost_em(ri));
fprintf('交付件已写出：outputs/result2_q2c.xlsx（%s，R=%d, K=%d）\n', run_name, S.R, S.K);
fprintf('  报送窗口 %d 天：计划购电费 %.2f + 紧急购电费 %.2f = %.2f 元\n', ...
        numel(ri), Z_plan, Z_em, Z_plan + Z_em);
fprintf('  窗口计划购电量 %.1f kWh，紧急购电量 %.1f kWh（%d 天出现）\n', ...
        sum(buy_m(ri,:), 'all'), tot_em, nnz(sum(em_m(ri,:), 2) > 1e-6));
fprintf('  （上一轮的 outputs/result2.xlsx 未被改动）\n');

%% 指定日期明细 → Markdown（人工核对与论文取数用；数字全部由本脚本从结果文件现算）
key_date = [datetime(2025,3,20); datetime(2025,6,21); datetime(2025,9,23); datetime(2025,12,21)];
nK = numel(key_date);
t3row = zeros(nK,1);
for k = 1:nK
    m = find(strcmp(tab.t3_date, tab.date_str{k}));
    assert(numel(m) == 1, '指定日期 %s 在紧急购电表中未唯一匹配', tab.date_str{k});
    t3row(k) = m;
end
lab2 = tab.t2_label;
for b = 1:numel(lab2)                                     % 模板格若为缺失，退回空串
    if ismissing(lab2{b}); lab2{b} = ''; end
end

fid = fopen(fullfile(PROJ_ROOT, 'outputs', 'q2c_指定日期表.md'), 'w', 'n', 'UTF-8');
mk = @(varargin) fprintf(fid, varargin{:});
mk('# 问题二 指定日期 表1~表3 明细（程序直出）\n\n');
mk('> 由 scripts/write_q2c_deliver.m 从 `final_results_q2c_%s.mat` 直出，未手抄。\n', run_name);
mk('> 口径（裁决 F1/F2、A5）：计划购电量 = G^plan·Δt；充放电量、紧急购电量取**真实附件2 数据下实际执行值**，\n');
mk('> 表中不含任何 SAA 情景平均值。时间标签为“起始时刻”，标签 t 代表时段 [t, t+10min)。\n');
mk('> 三张表的完整逐槽版本见交付结果表 result2_q2c.xlsx。\n\n');

% 表 1：整点 6 槽（与论文表 1 同口径）+ 全天合计 + 全天购电费
mk('## 表1 计划购电量（kWh）\n\n');
mk('| 日期 | %s | 全天合计 | 全天购电费(元) |\n', strjoin(tab.t1_label(:).', ' | '));
mk('|---|%s|---|---|\n', repmat('---|', 1, numel(tab.t1_label)));
for k = 1:nK
    mk('| %s | %s | %.2f | %.2f |\n', tab.date_str{k}, ...
       strjoin(arrayfun(@(x) sprintf('%.2f', x), tab.t1_buy(k,:), 'UniformOutput', false), ' | '), ...
       tab.t1_total(k), tab.t1_cost(k));
end
mk('\n');

% 表 2：6 个 4 小时时段汇总 + 0:00 / 24:00 储电量
mk('## 表2 充放电量（kWh，按题目 4 小时时段汇总）\n\n');
for k = 1:nK
    mk('### %s\n\n', tab.date_str{k});
    mk('| 时段 | 充电量 | 放电量 |\n|---|---|---|\n');
    for b = 1:tab.nB
        mk('| %s | %.2f | %.2f |\n', lab2{b}, tab.t2_chg(k,b), tab.t2_dis(k,b));
    end
    mk('\n本日 0:00 储电量 %.2f kWh，24:00 储电量 %.2f kWh；全天充电合计 %.2f kWh，放电合计 %.2f kWh。\n\n', ...
       tab.t2_E0(k), tab.t2_ET(k), sum(tab.t2_chg(k,:)), sum(tab.t2_dis(k,:)));
end

% 表 3：连续非零槽合并为连续时段（分段判据同 func_write_q2 的 em_windows：>1e-6；
% 时段标签 = 首槽起点 ~ 末槽终点，即“标签为起始时刻”口径）
mk('## 表3 紧急购电量（kWh，连续非零槽已合并为连续时段）\n\n');
mk('| 日期 | 时段 | 电量 |\n|---|---|---|\n');
for k = 1:nK
    d = t3row(k);
    row = em_m(ri(d), :);                                 % 该日的逐槽实际执行紧急购电量
    kk  = find(row > 1e-6);  kk = kk(:);                  % 列向量，便于下面的分段拼接
    if isempty(kk)
        mk('| %s | 无 | 0 |\n', tab.date_str{k});
        continue;
    end
    brk = [0; find(diff(kk) > 1); numel(kk)];             % 分段边界，同 func_write_q2 的 em_windows
    csum = cumsum(row);  seg_sum = 0;
    for j = 1:numel(brk) - 1
        i1 = kk(brk(j) + 1);  i2 = kk(brk(j + 1));
        e0 = 0;  if i1 > 1; e0 = csum(i1 - 1); end
        seg_sum = seg_sum + (csum(i2) - e0);
        mk('| %s | %s-%s | %.2f |\n', tab.date_str{k}, slot_lab(i1 - 1), slot_lab(i2), csum(i2) - e0);
    end
    assert(abs(seg_sum - tab.t3_kwh(d)) < 1e-6, '指定日期 %s 的紧急购电分段电量与交付表不符', tab.date_str{k});
    mk('| %s | 合计（%d 段） | %.2f |\n\n', tab.date_str{k}, numel(brk) - 1, seg_sum);
end
fclose(fid);
fprintf('指定日期明细已写出：outputs/q2c_指定日期表.md（%d 个日期）\n', nK);

% ---------------------------------------------------------------- 局部函数
function s = slot_lab(k)
% 第 k 个时刻标签（k 槽 = 10 分钟；k=0 得 0:00，k=144 得 24:00），同 func_write_q2 的 slot_time
m = k * 10;
s = sprintf('%d:%02d', floor(m/60), mod(m,60));
end
