function arch3 = func_resid_q3b(arch, fc3, pv_m, d_start)
%FUNC_RESID_Q3B  在问题二残差档案上，增建附件3 的分阶段光伏残差库
%
%   问题二的负荷/光伏残差直接沿用（arch.eL / arch.ePV，按钟点对齐）；
%   本函数新增**附件3 光伏预报误差**，按**发布时刻分的四个库**维护（裁决 C13/D6）：
%
%       e^{PV,s}_{r,ℓ} = PV^act(r, sl_s + ℓ) − interp( 附件3 日 r 阶段 s )(lead ℓ)
%
%   其中 s ∈ {0,6,12,18} 对应库号 j = 1..4，sl_s = 6s 为发布时刻在日内的槽偏移，
%   ℓ = 1..144 为**自发布时刻起的提前量**（裁决 D7）。
%   ℓ 超过当日剩余槽数时自然跨入次日——用全局线性索引取值即可，
%   且因历史日 r ≤ d−1 ≤ D−1，索引恒不越界。
%
%   一月（d_start 之前）按已知数据处理、不产生预报也就不产生残差（裁决 D5，与问题二同口径），
%   该区段的 ePV3 置 NaN。
%
%   输入  arch      func_resid_q2 的档案（含 eL / ePV / ok）
%         fc3       D×4×24 附件3 预报
%         pv_m      D×144 光伏实际（已按起始标签口径读入）
%         d_start   首个"需要预测"的日子（= 报告窗口首日）
%   输出  arch3     arch 之上新增字段：
%                     ePV3    D×144×4  附件3 分阶段残差（实际 − 插值预报）
%                     sl     1×4       各阶段的日内槽偏移 [0 36 72 108]
%                     d_start
%
%   用法示例：arch3 = func_resid_q3b(func_resid_q2(...), fc3, pv_m, d_start);

T = size(pv_m, 2);
D = size(pv_m, 1);
assert(size(fc3, 1) == D && size(fc3, 2) == 4 && size(fc3, 3) == 24, '附件3 维度不符');
assert(size(arch.eL, 1) == D && size(arch.eL, 2) == T, '问题二残差档案维度不符');

sl = [0, 36, 72, 108];                         % 0:00 / 6:00 / 12:00 / 18:00 的日内槽偏移
ePV3 = nan(D, T, 4);
% ★ 必须按**行主序**展平：pv_m(:) 是列主序（先跑完 365 天再换下一槽），
%   配合下面的 (r−1)*T+t 索引会取到别的日子——长度对得上、均值也接近，
%   只有分布被整体错配，表现为"情景光度虚高"这类**看起来只是数值偏大**的错。
pvl = [reshape(pv_m.', [], 1); pv_m(D, :).'];  % 行主序；末尾平延一天备跨日取值

for j = 1:4
    % 该阶段、该日、各提前量的插值预报（各日不同，逐日算）
    lead = 1:T;
    for r = 1:D
        f24 = squeeze(fc3(r, j, :)).';
        pvhat = func_interp_q3b(f24, T);       % 1×T
        g = (r - 1) * T + sl(j) + lead;        % 全局 1 基槽号（可跨入次日）
        % pvl 是列向量，用行索引取值返回的仍是列向量；必须转置成行再与 pvhat 相减，
        % 否则 144×1 与 1×144 会隐式广播成 144×144（MATLAB 的静默广播）
        ePV3(r, :, j) = pvl(g).' - pvhat;
    end
end

% 一月不进任何误差库（与问题二 ok 掩码同一节拍）
if d_start > 1
    ePV3(1:min(d_start-1, D), :, :) = NaN;
end

arch3 = arch;
arch3.ePV3 = ePV3;
arch3.sl = sl;
arch3.d_start = d_start;

% 数据合理性守卫：残差是"实际 − 预报"，其分布应与实际光伏同量级。
% 若索引错配（如列主序当行主序），残差本身仍有限值、均值也接近 0，
% 但**白天时段会出现明显偏正的均值**——这条断言专门拦这一类静默错配。
for j = 1:4
    day = ePV3(:, 37:120, j);                  % 白天时段（6:00–20:00）
    v = day(isfinite(day));
    assert(abs(mean(v)) < 1000, ...
        '附件3 残差（阶段 %d）白天均值 %+.1f kW 明显偏离 0，疑似情景数据索引错配', j, mean(v));
    assert(mean(abs(v)) < 3000, ...
        '附件3 残差（阶段 %d）白天平均绝对量 %.1f kW 过大，疑似索引错配', j, mean(abs(v)));
end

end
