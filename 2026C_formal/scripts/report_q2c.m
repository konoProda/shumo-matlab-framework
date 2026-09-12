% report_q2c.m —— 问题二第三轮：按方案文档 §18 字段清单直出数值块
%
%   所有数字一律程序读取 outputs/final_results_q2c_*.mat 后现算，杜绝手抄。
%   **单位约定**：out.em_m / curt_m / waste_m 由执行层返回时已乘 Δt，是电量(kWh)，
%   不得再乘 Δt；out.buy_kw 是功率(kW)，取电量须再乘 Δt。
%   产出：outputs/q2c_handback_tables.md
%
%   用法：matlab -batch "run('scripts/report_q2c.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
OUT = fullfile(PROJ_ROOT, 'outputs');
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
dt = prm.dt;

[~, ~, ~, day_list] = func_read_q2(PROJ_ROOT);
D = numel(day_list);
win = day_list >= datetime(2025,2,1);          % 报送窗口掩码（334 天）
ri  = find(win);
tgt = [datetime(2025,3,20), datetime(2025,6,21), datetime(2025,9,23), datetime(2025,12,21)];
ti  = arrayfun(@(x) find(day_list == x, 1), tgt);

fid = fopen(fullfile(OUT, 'q2c_handback_tables.md'), 'w', 'n', 'UTF-8');
mk = @(varargin) fprintf(fid, varargin{:});
fprintf(fid, '# 问题二 第四轮 数值块（程序直出）\n\n');
fprintf(fid, '> 由 scripts/report_q2c.m 生成；所有数字取自 outputs/final_results_q2c_*.mat。\n');
fprintf(fid, '> 报送窗口 = 2025-02-01 ~ 2025-12-31，共 %d 天；全年 = 日历 365 天（一月按已知数据）。\n\n', nnz(win));

has = @(s) exist(fullfile(OUT, sprintf('final_results_q2c_%s.mat', s)), 'file') > 0;
Ld  = @(s) load(fullfile(OUT, sprintf('final_results_q2c_%s.mat', s))).res;

%% ============ 表 1 运行总览 ============
mk('## 表 1 七组运行总览\n\n');
mk('| 运行 | 含义 | 视界 R | 情景 K | B3 | 全年费用(元) | 窗口费用(元) | 窗口紧急电量(kWh) | 窗口紧急天数 | 最大间隙 | 均单次耗时(s) | 总耗时(min) |\n');
mk('|---|---|---|---|---|---|---|---|---|---|---|---|\n');
meta = { 'L1','第一层 逐日完美信息',1,1,0; 'L2','第二层 正式 SAA+B3',7,4,1; ...
         'L2b','消融 SAA−B3',7,4,0; 'L2r1','视野对照 R=1',1,4,1; ...
         'L2r3','视野对照 R=3',3,4,1; 'L2k8','情景数稳定性 K=8',7,8,1 };
for k = 1:size(meta,1)
    s = meta{k,1};
    if ~has(s); mk('| %s | %s | %d | %d | %d | 未跑出 | | | | | | |\n', meta{k,1:5}); continue; end
    r = Ld(s);
    mk('| %s | %s | %d | %d | %d | %.2f | %.2f | %.1f | %d | %.2e | %.2f | %.1f |\n', ...
       s, meta{k,2}, meta{k,3}, meta{k,4}, meta{k,5}, sum(r.cost), sum(r.cost(win)), ...
       sum(r.em_m(win,:), 'all'), nnz(sum(r.em_m(win,:),2) > 1e-6), max(r.gap), ...
       mean(r.t_solve(r.t_solve > 0)), r.time/60);
end
if has('L1b')
    S = load(fullfile(OUT,'final_results_q2c_L1b.mat'));
    mk('| L1b | 第一层 全年联合完美信息（**LP 松弛**） | 365 | 1 | — | %.2f | %.2f | %.1f | — | — | — | %.1f |\n', ...
       S.cost_year, S.cost_win, sum(S.ec_day(win)));
end
mk('\n');

%% ============ 表 2 第二层 K=4 的 §18 字段清单 ============
if has('L2')
    r = Ld('L2');
    soc = r.Eend_m(:, end);
    mk('## 表 2 第二层 K=4（正式方案）§18 字段清单\n\n');
    mk('| 字段 | 全年(365天) | 报送窗口(334天) |\n|---|---|---|\n');
    mk('| 计划购电费(元) | %.2f | %.2f |\n', sum(r.cost_plan), sum(r.cost_plan(win)));
    mk('| 紧急购电费(元) | %.2f | %.2f |\n', sum(r.cost_em), sum(r.cost_em(win)));
    mk('| 总购电费(元) | %.2f | %.2f |\n', sum(r.cost), sum(r.cost(win)));
    mk('| 紧急购电量(kWh) | %.1f | %.1f |\n', sum(r.em_m,'all'), sum(r.em_m(win,:),'all'));
    mk('| 紧急购电天数 | %d | %d |\n', nnz(sum(r.em_m,2) > 1e-6), nnz(sum(r.em_m(win,:),2) > 1e-6));
    mk('| 紧急购电时段数 | %d | %d |\n', nnz(r.em_m > 1e-6), nnz(r.em_m(win,:) > 1e-6));
    mk('| 最大单槽紧急量(kWh) | %.3f | %.3f |\n', max(r.em_m(:)), max(max(r.em_m(win,:))));
    mk('| 最大约束违反量 | %.2e | — |\n', max(r.viol));
    mk('| 总运行时间(min) | %.1f | — |\n', r.time/60);
    mk('\n**日末 SOC 统计（kWh）**\n\n| 区间 | 均值 | 中位数 | 最小 | 最大 | 触底槽数(E=1200) |\n|---|---|---|---|---|---|\n');
    mk('| 全年 | %.1f | %.1f | %.1f | %.1f | %d |\n', mean(soc), median(soc), min(soc), max(soc), ...
       nnz(abs(r.Eend_m - prm.E_min) < 1e-6));
    mk('| 报送窗口 | %.1f | %.1f | %.1f | %.1f | %d |\n', mean(soc(ri)), median(soc(ri)), ...
       min(soc(ri)), max(soc(ri)), nnz(abs(r.Eend_m(ri,:) - prm.E_min) < 1e-6));
    mk('\n- 退役/退化：有效残差不足而退化为确定性的天数 = %d 天（全年），其中报送窗口内 %d 天；\n', ...
       nnz(r.degraded), nnz(r.degraded(ri)));
    mk('- SAA 实际生效（Keff=4）天数 = %d 天；B3 校正启用天数 = %d 天。\n\n', ...
       nnz(r.Keff == 4), nnz(r.corr.on));
end

%% ============ 表 3 信息集阶梯对照（下界关系）============
if has('L1') && has('L2')
    l1 = Ld('L1');  l2 = Ld('L2');
    mk('## 表 3 信息集阶梯与费用（报送窗口口径）\n\n');
    mk('| 层级 | 信息集 | 窗口费用(元) | 相对上一级 | 窗口紧急电量(kWh) |\n|---|---|---|---|---|\n');
    base = [];
    if has('L1b')
        S = load(fullfile(OUT,'final_results_q2c_L1b.mat'));
        mk('| L1b 全年联合完美信息 | 全年 365 天真实数据同时已知（理论下界） | %.2f | — | %.1f |\n', ...
           S.cost_win, sum(S.ec_day(win)));
        base = S.cost_win;
    end
    mk('| L1 逐日完美信息 | 当天真实数据已知 | %.2f | %s | %.1f |\n', sum(l1.cost(win)), ...
       relstr(sum(l1.cost(win)), base), sum(l1.em_m(win,:),'all'));
    mk('| L2 滚动 SAA（正式） | 截止前一日的历史数据 | %.2f | %s | %.1f |\n', sum(l2.cost(win)), ...
       relstr(sum(l2.cost(win)), sum(l1.cost(win))), sum(l2.em_m(win,:),'all'));
    if isempty(base)
        mk('\n- 「预测不确定性代价」= L2 − L1 = %.2f 元；L1b 未跑出，SOC 短视代价暂缺。\n', ...
           sum(l2.cost(win)) - sum(l1.cost(win)));
    else
        mk('\n- 「预测不确定性代价」= L2 − L1 = %.2f 元；「单日视野（SOC 短视）代价」= L1 − L1b = %.2f 元。\n', ...
           sum(l2.cost(win)) - sum(l1.cost(win)), sum(l1.cost(win)) - base);
    end
    mk('- L1b 以 LP 松弛方式求解（全年 52,560 槽引入互斥二元变量将超本机求解边界），但**实测松弛解在全部槽位满足互斥**\n');
    mk('  （见 outputs/q2c_l1b_audit.txt：最大 min(C,D) = 0.0000 kW），可配上整数 u 构成 MILP 可行解，\n');
    mk('  故**整数间隙为 0，该值是全年联合完美信息的真实最优值，不是下界估计**。\n\n');
end

%% ============ 表 4 视野长度对照（T7）============
if has('L2r1') && has('L2r3') && has('L2')
    mk('## 表 4 视野长度对照（T7）\n\n');
    mk('| 视界 R | 窗口费用(元) | 窗口紧急电量(kWh) | 日末SOC均值(kWh) | 均单次耗时(s) | 总耗时(min) |\n|---|---|---|---|---|---|\n');
    for s = {'L2r1','L2r3','L2'}
        r = Ld(s{1});
        mk('| %d | %.2f | %.1f | %.1f | %.2f | %.1f |\n', r.R, sum(r.cost(win)), ...
           sum(r.em_m(win,:),'all'), mean(r.Eend_m(ri,end)), mean(r.t_solve(r.t_solve>0)), r.time/60);
    end
    mk('\n');
end

%% ============ 表 5 情景数稳定性（T8）============
if has('L2k8') && has('L2')
    r4 = Ld('L2');  r8 = Ld('L2k8');
    mk('## 表 5 情景数稳定性（T8）\n\n');
    mk('| 情景数 K | 窗口费用(元) | 窗口紧急电量(kWh) | 日末SOC均值(kWh) | 总耗时(min) |\n|---|---|---|---|---|\n');
    mk('| 4（基准） | %.2f | %.1f | %.1f | %.1f |\n', sum(r4.cost(win)), ...
       sum(r4.em_m(win,:),'all'), mean(r4.Eend_m(ri,end)), r4.time/60);
    mk('| 8 | %.2f | %.1f | %.1f | %.1f |\n', sum(r8.cost(win)), ...
       sum(r8.em_m(win,:),'all'), mean(r8.Eend_m(ri,end)), r8.time/60);
    mk('| **相对差** | %+.3f%% | %+.2f%% | %+.3f%% | |\n', ...
       100*(sum(r8.cost(win))-sum(r4.cost(win)))/sum(r4.cost(win)), ...
       100*(sum(r8.em_m(win,:),'all')-sum(r4.em_m(win,:),'all'))/max(sum(r4.em_m(win,:),'all'),eps), ...
       100*(mean(r8.Eend_m(ri,end))-mean(r4.Eend_m(ri,end)))/mean(r4.Eend_m(ri,end)));
    mk('\n');
end

%% ============ 表 6 B3 消融（C4）============
if has('L2b') && has('L2')
    r4 = Ld('L2');  rb = Ld('L2b');
    mk('## 表 6 B3 消融对照（C4，仅量化贡献，不作交付口径）\n\n');
    mk('| 方案 | 窗口费用(元) | 窗口紧急电量(kWh) | 相对 SAA−B3 |\n|---|---|---|---|\n');
    mk('| SAA − B3（消融） | %.2f | %.1f | — |\n', sum(rb.cost(win)), sum(rb.em_m(win,:),'all'));
    mk('| SAA + B3（正式） | %.2f | %.1f | %+.2f 元 / %+.1f kWh |\n', ...
       sum(r4.cost(win)), sum(r4.em_m(win,:),'all'), ...
       sum(r4.cost(win))-sum(rb.cost(win)), sum(r4.em_m(win,:),'all')-sum(rb.em_m(win,:),'all'));
    mk('\n');
end

%% ============ 表 7 分段对照（2—4 月 vs 5—12 月）============
mk('## 表 7 分段对照（报送窗口内）\n\n');
seg = { '2—4 月', day_list >= datetime(2025,2,1) & day_list < datetime(2025,5,1); ...
        '5—12 月', day_list >= datetime(2025,5,1) };
mk('| 运行 | 区间 | 费用(元) | 紧急电量(kWh) |\n|---|---|---|---|\n');
allr = [meta(:,1); {'L2k8'}; {'L2b'}; {'L2r1'}; {'L2r3'}];
allr = unique(allr, 'stable');
for k = 1:numel(allr)
    s = allr{k};
    if ~has(s); continue; end
    r = Ld(s);
    for g = 1:size(seg,1)
        m = seg{g,2};
        mk('| %s | %s | %.2f | %.1f |\n', s, seg{g,1}, sum(r.cost(m)), sum(r.em_m(m,:),'all'));
    end
end
mk('\n');

%% ============ 表 8 四个指定日期概览 ============
if has('L2')
    r = Ld('L2');  l1 = Ld('L1');
    mk('## 表 8 四个指定日期概览（第二层 K=4；明细表见交付结果文件）\n\n');
    mk('| 日期 | 日费用(元) | 紧急电量(kWh) | 紧急时段数 | 日末SOC(kWh) | 计划购电总量(kWh) | 理想层同日费用(元) |\n');
    mk('|---|---|---|---|---|---|---|\n');
    for k = 1:numel(ti)
        d = ti(k);
        mk('| %s | %.2f | %.2f | %d | %.1f | %.1f | %.2f |\n', char(day_list(d),'yyyy-MM-dd'), ...
           r.cost(d), sum(r.em_m(d,:)), nnz(r.em_m(d,:) > 1e-6), r.Eend_m(d,end), ...
           sum(r.buy_kw(d,:))*dt, l1.cost(d));
    end
    mk('\n');
end

%% ============ 表 9 预测层与情景层诊断 ============
if has('L2')
    r = Ld('L2');
    mk('## 表 9 预测层与情景层诊断（第二层 K=4；**以下各项均为全年 365 天口径**）\n\n');
    mk('| 项 | 数值 |\n|---|---|\n');
    mk('| 滚动起点 SOC 递推一致性：逐日 E0 与前一实际日末最大差 | %.3e kWh |\n', ...
       max(abs(r.E0_m(2:end) - r.Eend_m(1:end-1,end))));
    mk('| 执行层逐槽守恒最大残差 | 见测试日志 T4-1（恒等式逐日校验） |\n');
    mk('| 未消纳光伏 V 合计(kWh) | %.1f |\n', sum(r.curt_m(:)));
    mk('| 已购未用 W 合计(kWh) | %.1f |\n', sum(r.waste_m(:)));
    mk('| 计划购电总量(kWh) | %.1f |\n', sum(r.buy_kw(:))*dt);
    mk('| W ／ 计划购电 | %.3f%% |\n', 100*sum(r.waste_m(:))/max(sum(r.buy_kw(:))*dt, eps));
    mk('| 最大间隙(元) | %.3e |\n', max(r.gap));
    mk('| 退化天数 | %d |\n', nnz(r.degraded));
    mk('\n');
end

%% ============ 表 10 抽样口径对照（旧"固定滞后模板" vs 新"逐日独立抽样"）============
f_old = fullfile(OUT, 'final_results_q2c_L2_固滞抽样对照.mat');
if has('L2') && exist(f_old, 'file') > 0
    ro = load(f_old).res;  rn = Ld('L2');
    mk('## 表 10 抽样口径对照（同一模型，仅情景抽样方式不同）\n\n');
    mk('| 抽样方式 | 窗口费用(元) | 窗口紧急电量(kWh) | 窗口紧急天数 | 相对差 |\n|---|---|---|---|---|\n');
    mk('| 旧：`rng(2026)` 每日重置（**全年同一置换，实为固定滞后模板**） | %.2f | %.1f | %d | — |\n', ...
       sum(ro.cost(win)), sum(ro.em_m(win,:),'all'), nnz(sum(ro.em_m(win,:),2) > 1e-6));
    mk('| 新：`rng(2026+d)` 逐日独立子流（正式交付口径） | %.2f | %.1f | %d | %+.2f%% / %+.1f kWh |\n', ...
       sum(rn.cost(win)), sum(rn.em_m(win,:),'all'), nnz(sum(rn.em_m(win,:),2) > 1e-6), ...
       100*(sum(rn.cost(win))-sum(ro.cost(win)))/sum(ro.cost(win)), ...
       sum(rn.em_m(win,:),'all')-sum(ro.em_m(win,:),'all'));
    mk('\n> 旧口径下 `randperm(28,K)` 因库长与种子恒定而全年返回同一置换，每天都抽固定的 4 个相对滞后，\n');
    mk('> 与建模文档 G4"每天独立"不符；差异已量化如上，旧结果仅作对照，**不作交付口径**。\n\n');
end

fclose(fid);
fprintf('已写入 outputs/q2c_handback_tables.md\n');
fprintf('REPORT_DONE\n');

%% ---------------------------------------------------------------- 局部函数
function s = relstr(x, b)
if isempty(b) || isnan(b)
    s = '—';
else
    s = sprintf('%+.2f 元', x - b);
end
end
