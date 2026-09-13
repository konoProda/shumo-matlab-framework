function [bL, bPV, info] = func_bias_q2(arch, day_list, d, cfg)
%FUNC_BIAS_Q2  求决策日 d 的分时偏差校正量 b^X(d,h)（预测层偏差校正 第二步）
%
%   窗口：最近 cfg.W 个**已完成**自然日 [d-W, d-1]，严格早于决策日。
%   粒度：小时——同小时 6 个槽共享同一校正量；先算每个历史日该小时 6 槽的平均残差，
%         再对有效历史日等权平均。
%   分组：负荷 优先"同小时＋同日类型"（工作日/周末），有效日不足 cfg.min_days 时退至
%         "同小时＋全部日类型"，仍不足则取 0；
%         光伏 只用"同小时＋全部日类型"，不足则取 0。
%   夜间保护：窗口内该小时的实际光伏全为 0（按 cfg.pv_zero_tol 的功率容差判零——
%             附件2 夜间存在 0.002 kW 量级的数值噪声）时，校正量取 0（不凭空造光伏）。
%
%   校正量是**有符号**的：低估负荷 → 正；高估光伏 → 负。
%
%   输入  arch      func_resid_q2 的档案
%         day_list  D×1 日期
%         d         决策日索引
%         cfg       含 W / min_days
%   输出  bL / bPV  24×1 负荷/光伏校正量
%         info      有效日数、回退层级、窗口与日类型计数

D = size(arch.eL, 1);
W = cfg.W;  m = cfg.min_days;
if ~isfield(cfg, 'pv_zero_tol') || isempty(cfg.pv_zero_tol); cfg.pv_zero_tol = 1; end

lo = max(1, d - W);  hi = d - 1;
if hi < 1; lo = 1; hi = 0; end        % 决策日之前没有已完成日 → 空窗口，走零校正
sidx = (lo:hi).';
assert(isempty(sidx) || max(sidx) < d, '信息泄漏：校正窗口包含决策日及其后');

% 只统计**真的发过预报**的日子：报告窗口之前（一月）按已知数据处理、不产生残差，
% 其残差为 NaN 且 ok = false，必须排除（否则会被当成零误差稀释校正量）。
sidx = sidx(arch.ok(sidx));

% 逐日逐小时的平均残差与有效性（该小时 6 槽全为有限值才算有效）
EL = hourly_stat(arch.eL,  'mean');
VL = hourly_stat(arch.eL,  'valid');
EP = hourly_stat(arch.ePV, 'mean');
VP = hourly_stat(arch.ePV, 'valid');

iswk   = ~isweekend(day_list);
tgt_wk = ~isweekend(day_list(d));

bL = zeros(24,1);   bPV = zeros(24,1);
info = struct('win', [lo hi], 'nL', zeros(24,1), 'lvlL', zeros(24,1), ...
              'nPV', zeros(24,1), 'lvlPV', zeros(24,1), ...
              'n_daytype', nnz(iswk(sidx) == tgt_wk), 'n_win', numel(sidx), ...
              'n_fb', nnz(arch.fb(sidx)));
info.lvlL = 3 * ones(24,1);   info.lvlPV = 2 * ones(24,1);

if isempty(sidx)
    % 窗口内一个预报日都没有（如 2 月 1—5 日）→ 校正量全 0
    info.win_biasL = NaN;   info.win_biasPV = NaN;
    return;
end

for h = 1:24
    % ---- 负荷 ----
    sel = sidx(iswk(sidx) == tgt_wk & VL(sidx,h));
    if numel(sel) >= m
        bL(h) = mean(EL(sel,h));   info.nL(h) = numel(sel);   info.lvlL(h) = 1;
    else
        sel = sidx(VL(sidx,h));
        if numel(sel) >= m
            bL(h) = mean(EL(sel,h));   info.nL(h) = numel(sel);   info.lvlL(h) = 2;
        else
            info.nL(h) = numel(sel);                              % 保持 0
        end
    end

    % ---- 光伏（同小时＋全部日类型）----
    sl = (h-1)*6 + (1:6);
    sel = sidx(VP(sidx,h));
    info.nPV(h) = numel(sel);
    if max(arch.PVact(sidx, sl), [], 'all') < cfg.pv_zero_tol   % 窗口内该小时光伏全为 0
        bPV(h) = 0;
    elseif numel(sel) >= m
        bPV(h) = mean(EP(sel,h));   info.lvlPV(h) = 1;
    end
end

% 窗口内原始残差的均值（诊断用；"截断后的实际偏差"在诊断报告中按校正后预测重新统计）
info.win_biasL  = mean(arch.eL(sidx,:),  'all');
info.win_biasPV = mean(arch.ePV(sidx,:), 'all');

end

% ---------------------------------------------------------------- 局部函数
function M = hourly_stat(e, kind)
% 逐日逐小时统计：'mean' 返回 D×24 的每小时平均，'valid' 返回 D×24 的有效性
D = size(e, 1);   T = size(e, 2);
E3 = reshape(e.', 6, T/6, D);            % 6 槽 × 24 小时 × D 天
switch kind
    case 'mean'
        M = squeeze(mean(E3, 1)).';      % D×24
    case 'valid'
        M = squeeze(all(isfinite(E3), 1)).';
    otherwise
        error('未知统计类型：%s', kind);
end
end
