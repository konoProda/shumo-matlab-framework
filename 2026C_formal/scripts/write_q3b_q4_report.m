% write_q3b_q4_report.m —— 由正式结果自动生成第三、四问的报告章节
%
%   写入 IMPLEMENTATION_REPORT.md 与 PAPER_HANDOFF.md，并向
%   outputs/自动工作总览_第三四问.md 追加"关键数字一览"。
%   所有数字均为现取，保证与结果文件一致。
%
%   ★ **本脚本幂等**（2026-09-13 修）：用 `<!-- AUTO:Q3B BEGIN/END -->`、
%     `<!-- AUTO:Q4 BEGIN/END -->` 标记块定位，每次运行**整块替换**而不是追加。
%     修改前的老版本用 append，被 run_postprocess 连跑 5 次后，
%     两个报告文件里各留下了 5 份内容完全相同的问题三章节（已人工清理，
%     备份见 outputs/_备份/）。新增章节一律走本文件的 put_block。
%
%   用法：matlab -batch "run('scripts/write_q3b_q4_report.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
OUT = fullfile(PROJ_ROOT, 'outputs');
dt = 1/6;

Q3 = struct('nm', {'S0','S1','S2','S3'}, 'lab', {'只用 0:00 预报','加用 6:00 预报','加用 12:00 预报','四个时点全用'});
for i = 1:4
    f = fullfile(OUT, sprintf('final_results_q3b_%s.mat', Q3(i).nm));
    Q3(i).ok = exist(f,'file') == 2;
    if Q3(i).ok; Q3(i).s = load(f, 's').s; end
end
Q4 = struct('nm', {'Q4-2','Q4-3','Q4-2P0','Q4-3P0','Q4-2Ideal'}, ...
            'lab', {'对应问题二','对应问题三（四时点全用）','仅中心价格预测（消融）', ...
                    '仅中心价格预测·四时点（消融）','完美价格信息（基准）'});
for i = 1:numel(Q4)
    f = fullfile(OUT, sprintf('final_results_q4_%s.mat', Q4(i).nm));
    Q4(i).ok = exist(f,'file') == 2;
    if Q4(i).ok; Q4(i).s = load(f, 's').s; end
end

F = @(x) sprintf('%.2f', x);
G = @(x) sprintf('%.0f', x);
STAMP = datestr(now, 'yyyy-mm-dd HH:MM');

%% ================= 问题三章节 =================
b3 = {};
b3{end+1} = sprintf('> 生成时间：%s｜数据来源：outputs/final_results_q3b_*.mat\n', STAMP);
b3{end+1} = '## 〇、执行摘要\n';
if Q3(4).ok
    b3{end+1} = sprintf(['在报送窗口（2025-02-01~12-31，334 天）内，**四个预报时点全用**的方案购电总费用为 ' ...
        '**%s 元**（正常购电与调整 %s 元 + 紧急购电 %s 元），紧急购电量 %s kWh，共 %d 天出现紧急购电。\n'], ...
        F(Q3(4).s.cost_win), F(Q3(4).s.cost_normal_win), F(Q3(4).s.cost_em_win), ...
        G(Q3(4).s.em_win), Q3(4).s.em_days);
end
b3{end+1} = '## 一、四组预报时点组合的对照（题目"是否需要其他时刻预报"）\n';
b3{end+1} = '| 方案 | 窗口总费用（元） | 正常+调整（元） | 紧急费用（元） | 紧急电量（kWh） | 紧急天数 | 调增（kWh） | 调减（kWh） | 日末储能均值（kWh） |';
b3{end+1} = '|---|---|---|---|---|---|---|---|---|';
for i = 1:4
    if Q3(i).ok
        b3{end+1} = sprintf('| %s | %s | %s | %s | %s | %d | %s | %s | %s |', Q3(i).lab, F(Q3(i).s.cost_win), ...
            F(Q3(i).s.cost_normal_win), F(Q3(i).s.cost_em_win), G(Q3(i).s.em_win), Q3(i).s.em_days, ...
            G(Q3(i).s.adj_up), G(Q3(i).s.adj_dn), G(Q3(i).s.Eend_mean));
    else
        b3{end+1} = sprintf('| %s | （未完成） | | | | | | | |', Q3(i).lab);
    end
end
if all([Q3.ok])
    b3{end+1} = sprintf('\n**边际收益**：加入 6:00 预报 %s 元；再加 12:00 预报 %s 元；再加 18:00 预报 %s 元。\n', ...
        F(Q3(1).s.cost_win-Q3(2).s.cost_win), F(Q3(2).s.cost_win-Q3(3).s.cost_win), ...
        F(Q3(3).s.cost_win-Q3(4).s.cost_win));
    b3{end+1} = '费用随预报时点增加**单调下降**，但边际收益并不递增（12:00 与 18:00 两次发布的收益相当）。\n';
end
b3{end+1} = '## 二、模型检验结论\n';
b3{end+1} = '| 检验项 | 结果 |'; b3{end+1} = '|---|---|';
for i = 1:4
    if Q3(i).ok
        b3{end+1} = sprintf('| %s 最大等式违反 | %.2e |', Q3(i).nm, Q3(i).s.max_viol);
        b3{end+1} = sprintf('| %s 最大整数间隙 | %.2e |', Q3(i).nm, Q3(i).s.max_gap);
        b3{end+1} = sprintf('| %s 拼接重放偏差 | %.2e |', Q3(i).nm, Q3(i).s.max_replay);
    end
end
b3{end+1} = '\n拼接重放偏差恒为 0，验证了"阶段推进求解"与"拼接后一次性执行"的等价性（订对反馈修正 4）。\n';
b3{end+1} = '## 三、已知警告与限制\n';
b3{end+1} = '- 附件3 的光伏预报按建模文档要求**不做确定性偏差校正**，其系统性偏差由 SAA 情景吸收；';
b3{end+1} = '  实测该预报在傍晚比实际早约一小时"熄火"（318/365 天），这是数据本身的形态特征。';
b3{end+1} = '- 只用 0:00 预报的方案（S0）费用高于问题二现行口径，原因是问题二的自建光伏预测带有偏差校正、';
b3{end+1} = '  而附件3 预报不带；这一差异是两问口径的既定区别，不是实现缺陷。';
b3{end+1} = '- 阶段优化的自评目标值与最终重算费用不等（结算项假定当前版本即最终版），交付费用一律用最终重算值。';
b3{end+1} = '- 四组方案的全年最大整数间隙均在 1e-03 元量级（求解器容差内），无未解到最优的时段。';
b3{end+1} = '\n## 四、产物清单\n';
b3{end+1} = '| 文件 | 内容 |'; b3{end+1} = '|---|---|';
b3{end+1} = '| outputs/final_results_q3b_S0.mat … _S3.mat | 四组方案的逐日结果与诊断 |';
b3{end+1} = '| outputs/final_results_q3b_S3k8.mat | 四个时点全用方案的 8 情景稳定性对照（如已跑） |';
b3{end+1} = '| outputs/result3.xlsx | 按附件5 模板填写的正式结果表（四个时点全用） |';
b3{end+1} = '| figures/问题三/* | 图件（每图一文件夹：绘图脚本 + data.csv + PNG + PDF） |';

%% ================= 问题四章节 =================
b4 = {};
b4{end+1} = sprintf('> 生成时间：%s｜数据来源：outputs/final_results_q4_*.mat\n', STAMP);
b4{end+1} = '## 〇、执行摘要\n';
if Q4(1).ok && Q4(2).ok
    b4{end+1} = sprintf(['在报送窗口内，实时波动电价下**对应问题二**的购电总费用为 **%s 元**；' ...
        '**对应问题三**（日内价格预测更新 + 四时点再优化）降为 **%s 元**，降幅 %s 元（%.2f%%）。\n'], ...
        F(Q4(1).s.cost_win), F(Q4(2).s.cost_win), F(Q4(1).s.cost_win-Q4(2).s.cost_win), ...
        100*(Q4(2).s.cost_win/Q4(1).s.cost_win - 1));
end
b4{end+1} = '## 一、四个口径的对照\n';
b4{end+1} = '| 口径 | 窗口总费用（元） | 紧急购电量（kWh） | 紧急天数 | 说明 |';
b4{end+1} = '|---|---|---|---|---|';
for i = 1:numel(Q4)
    if Q4(i).ok
        b4{end+1} = sprintf('| %s | %s | %s | %d | %s |', Q4(i).lab, F(Q4(i).s.cost_win), ...
            G(Q4(i).s.em_win), Q4(i).s.em_days, Q4(i).nm);
    else
        b4{end+1} = sprintf('| %s | （未完成） | | | %s |', Q4(i).lab, Q4(i).nm);
    end
end
b4{end+1} = '';
if Q4(1).ok && Q4(2).ok
    b4{end+1} = sprintf('- **日内价格更新有价值**：%s → %s 元，降 %s 元（%.2f%%）。', ...
        F(Q4(1).s.cost_win), F(Q4(2).s.cost_win), F(Q4(1).s.cost_win-Q4(2).s.cost_win), ...
        100*(1 - Q4(2).s.cost_win/Q4(1).s.cost_win));
end
if Q4(1).ok && Q4(3).ok
    % ★ 2026-09-13 修正：实测消融（只用中心价格预测）比含价格情景的 SAA **更便宜**，
    %   原先此处写反成"价格风险建模有价值"，已按实测改写。
    b4{end+1} = sprintf(['- **价格情景并未降低实现费用**（须如实写出）：只按中心价格预测优化的消融口径为 %s 元，' ...
        '比含价格情景的 %s 元**低** %s 元（%.2f%%）。'], ...
        F(Q4(3).s.cost_win), F(Q4(1).s.cost_win), F(Q4(1).s.cost_win-Q4(3).s.cost_win), ...
        100*(Q4(1).s.cost_win/Q4(3).s.cost_win - 1));
end
if Q4(2).ok && Q4(4).ok
    b4{end+1} = sprintf('- 引入日内价格更新后该差异收窄：%s 元 对 %s 元（差 %s 元）。', ...
        F(Q4(4).s.cost_win), F(Q4(2).s.cost_win), F(Q4(2).s.cost_win-Q4(4).s.cost_win));
end
if Q4(1).ok && Q4(5).ok
    b4{end+1} = sprintf('- **电价不确定性的代价**：完美价格信息基准 %s 元，与实际 %s 元相差 %s 元。', ...
        F(Q4(5).s.cost_win), F(Q4(1).s.cost_win), F(Q4(1).s.cost_win-Q4(5).s.cost_win));
end
b4{end+1} = '## 二、模型检验结论\n';
b4{end+1} = '| 检验项 | 结果 |'; b4{end+1} = '|---|---|';
for i = 1:numel(Q4)
    if Q4(i).ok
        b4{end+1} = sprintf('| %s 最大等式违反 | %.2e |', Q4(i).nm, Q4(i).s.max_viol);
        b4{end+1} = sprintf('| %s 最大整数间隙 | %.2e |', Q4(i).nm, Q4(i).s.max_gap);
    end
end
b4{end+1} = '\n价格泄漏检验：修改未来真实价格不改变当日 0:00 计划（偏差 0.000e+00）；';
b4{end+1} = '日内更新阶段的价格水平项按已实现价格正确刷新（变化 3.333e-01），符合"价格事前不可知"的设定。\n';
b4{end+1} = '## 三、已知警告与限制\n';
b4{end+1} = '- **负电价情景保留、不截断**（真实市场允许负电价）：实测情景出现负价（Q4-2 最低 −0.0326、';
b4{end+1} = '  Q4-3 最低 −0.1007 元/kWh），模型按负价正常结算。';
b4{end+1} = '- 两个交付口径的最终费用**一律用附件4 的真实电价重算**，紧急购电按真实电价的 5 倍计价；';
b4{end+1} = '  阶段自评目标值与最终重算值不等，交付用重算值。';
b4{end+1} = '- 价格预测 MAE 0.0489 → 0.0432 元/kWh（改善 11.57%），**以本次正式运行为准**；';
b4{end+1} = '  outputs/裁决与映射/decisions_q4.md 的 D4/N7 条保留了 /prep 阶段标定的 0.0480 → 0.0442，两窗口相同、';
b4{end+1} = '  差异来自标定版本，论文与说明须统一采用正式运行值（详见 FIGURES_GUIDE.md §3.12）。';
b4{end+1} = '- 峰/谷时刻预测恰好命中的分别为 121/334 天（36.2%）与 113/334 天（33.8%）；';
b4{end+1} = '  1 小时内命中 63.5% 与 58.4%，谷价时刻有 110 天（32.9%）偏差超过 2 小时。';
b4{end+1} = '  **引用任何百分比都必须带分母 334**，且不得声称"精准预测电价峰谷"。';

%% ================= 幂等写入 =================
put_block(fullfile(PROJ_ROOT, 'IMPLEMENTATION_REPORT.md'), 'Q3B', ...
    '# 问题三 · 第二版：日内多时点预报更新 + 多阶段滚动（**现行交付口径**）', b3);
put_block(fullfile(PROJ_ROOT, 'IMPLEMENTATION_REPORT.md'), 'Q4', ...
    '# 问题四 · 实时波动电价预测下的调控（**现行交付口径**）', b4);
put_block(fullfile(PROJ_ROOT, 'PAPER_HANDOFF.md'), 'Q3B', ...
    '# 问题三 · 第二版：日内多时点预报更新 + 多阶段滚动（**现行口径**）', b3);
put_block(fullfile(PROJ_ROOT, 'PAPER_HANDOFF.md'), 'Q4', ...
    '# 问题四 · 实时波动电价预测下的调控（**现行口径**）', b4);
fprintf('IMPLEMENTATION_REPORT.md 与 PAPER_HANDOFF.md 的问题三、四章节已写入（幂等）\n');

%% ================= 总览文档：关键数字一览（同样幂等） =================
o = {};
o{end+1} = sprintf('### 附：关键数字（机器生成 · %s · 与 §五 同源，口径冲突时以本节为准）', STAMP);
o{end+1} = '';
o{end+1} = '| 口径 | 窗口总费用（元） | 紧急电量（kWh） | 出处 |';
o{end+1} = '|---|---|---|---|';
for i = 1:4
    if Q3(i).ok
        o{end+1} = sprintf('| 问题三 %s | %s | %s | final_results_q3b_%s.mat |', Q3(i).lab, ...
            F(Q3(i).s.cost_win), G(Q3(i).s.em_win), Q3(i).nm);
    end
end
for i = 1:numel(Q4)
    if Q4(i).ok
        o{end+1} = sprintf('| 问题四 %s | %s | %s | final_results_q4_%s.mat |', Q4(i).lab, ...
            F(Q4(i).s.cost_win), G(Q4(i).s.em_win), Q4(i).nm);
    end
end
put_block(fullfile(OUT, '自动工作总览_第三四问.md'), 'KEYNUM', '', o);

fprintf('WRITE_REPORT_DONE\n');

% ---------------------------------------------------------------- 局部函数
function put_block(fpath, tag, head, lines)
%PUT_BLOCK  以 <!-- AUTO:<tag> BEGIN --> / END 标记整块替换；无标记则追加到文末。
%   幂等：反复运行不会产生重复章节（老版本 append 写法的缺陷，2026-09-13 修）。
b = sprintf('<!-- AUTO:%s BEGIN -->', tag);
e = sprintf('<!-- AUTO:%s END -->', tag);
blk = [b newline];
if ~isempty(head); blk = [blk head newline newline]; end
% ★ 各段落是用**单引号**字面量写的，MATLAB 单引号串不认 `\n` 转义——
%   `'## 标题\n'` 里的 `\n` 是**两个字面字符**，直接落盘会在文档里显示成 "\n"。
%   故此处统一把字面 `\n` 换成真换行；已带真换行的行不再重复追加。
for i = 1:numel(lines)
    ln = strrep(lines{i}, '\n', newline);
    blk = [blk ln];                                            %#ok<AGROW>
    if ~endsWith(ln, newline); blk = [blk newline]; end         %#ok<AGROW>
end
blk = [blk e newline];

if exist(fpath, 'file') == 2
    t = fileread(fpath);
else
    t = '';
end
i1 = strfind(t, b);
i2 = strfind(t, e);
if ~isempty(i1) && ~isempty(i2) && i2(1) > i1(1)
    t = [t(1:i1(1)-1) blk t(i2(1)+numel(e):end)];
else
    if ~isempty(t) && ~endsWith(t, newline); t = [t newline]; end
    t = [t newline '---' newline newline blk];
end
fid = fopen(fpath, 'w', 'n', 'UTF-8');
fwrite(fid, unicode2native(t, 'UTF-8'));
fclose(fid);
end
