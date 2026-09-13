function P = func_price_q4(PROJ_ROOT, prm, cfg)
%FUNC_PRICE_Q4  问题四：电价读取、中心预测、偏差校正与分阶段残差库
%
%   电价预测沿用项目内"同周期回溯 + 偏差校正"思路（裁决 C1）：
%     基础预测 π̂^base = 同星期回溯（严格早于决策日的最近 Kfc 个同星期日的均值）
%     偏差校正 b(h)   = 最近 W 个已完成日的同小时残差均值（不按日型分组，裁决 D4：
%                       基础预测已吸收日型效应——实测周五/周六均价 0.629 vs 其余 ~0.82 元/kWh；
%                       再叠加周末/工作日分组反而会把周五错分）
%
%   日内水平项（裁决 D-08，经建模侧确认的因果公式）：
%     阶段 s 时，当天已实现时段 Ω_s 相对 0:00 预测的平均偏差
%         L_{d,s} = mean_{t∈Ω_s} [ π^act_{d,t} − π̂^{(d,0)}_{d,t} ]
%     加到当天全部尚未执行时段：π̂^{(d,s)}_{d,t} = π̂^{(d,0)}_{d,t} + L_{d,s}（t > sl）
%     未来日不变（次日 0:00 完全重建，避免引入无依据的跨日衰减系数）。
%     只使用已实现价格 ⇒ 不构成未来信息泄漏。
%
%   分阶段残差库（§20，与问题三附件3 库同构，按发布时刻的提前量对齐）：
%     e^{π,s}_{r,ℓ} = 事后实际 − 若在 (r,s) 做预测会给出的值
%                   = e^{π,0}_{r, 钟点} − L_{r,s}
%   其中 L_{r,s} 是该历史日已实现时段上的水平项。四个库互不相同（§20 要求分池）。
%
%   输入  PROJ_ROOT / prm / cfg（Kfc, W, min_days, d_start）
%   输出  P 结构体：
%         price_act  D×T   附件4 实际电价（已按数据索引归位）
%         pr1        T×1   附件1 典型日电价（冷启动回退）
%         pi_base    D×T   基础预测（同星期回溯，因果）
%         pi_hat0    D×T   0:00 中心预测（基础 + 历史偏差校正）
%         ePi0       D×T   0:00 口径残差（实际 − 中心预测），一月为 NaN
%         ePi3       D×144×4  分阶段提前量对齐残差
%         L_day      D×4   各历史日在各阶段已实现时段上的水平项（诊断留档）
%         ok         D×1   有效残差日掩码（= 问题二口径的 ok）

proc = fullfile(PROJ_ROOT, 'data', '附件');
T = prm.T;
raw = readcell(fullfile(proc, '附件4.xlsx'), 'Sheet', 'Sheet1');
assert(size(raw,2) == 1 + T, '附件4 列数不符');
Pr = cell2mat(raw(2:end, 2:end));
D = size(Pr, 1);
% 附件4 与附件2 表头逐列同源 ⇒ 沿用问题二已确认的数据索引归位（裁决 A2）
price_act = [[Pr(1,T); Pr(1:D-1,T)], Pr(:, 1:T-1)];

raw1 = readcell(fullfile(proc, '附件1.xlsx'), 'Sheet', 'Sheet1');
pr1 = cell2mat(raw1(2:1+T, 2));  pr1 = pr1([T, 1:T-1]);

%% 基础预测与 0:00 中心预测（逐日因果）
% 逐日模式：第 d 行即"在 d 的 0:00 用严格早于 d 的历史所作的第 d 天预测"，一次算完全年
pi_base = func_forecast_q2(price_act, price_act, pr1, pr1, cfg.Kfc);

% 残差档案（实际 − 基础预测），一月不产生残差
ePiBase = price_act - pi_base;
hidx = floor((0:T-1)/6) + 1;
ok = false(D,1);  if cfg.d_start <= D; ok(cfg.d_start:D) = true; end

% 逐小时偏差校正：最近 W 个已完成有效日
ePi0 = nan(D, T);
pi_hat0 = zeros(D, T);
b_hist = zeros(D, 24);
for d = 1:D
    lo = max(1, d - cfg.W);  hi = d - 1;
    idx = (lo:hi).';  idx = idx(ok(idx));
    if numel(idx) < cfg.min_days
        b = zeros(24,1);
    else
        b = zeros(24,1);
        for h = 1:24
            cols = (h-1)*6 + (1:6);
            b(h) = mean(mean(ePiBase(idx, cols), 2));
        end
    end
    b_hist(d,:) = b.';
    pi_hat0(d, :) = pi_base(d, :) + b(hidx).';
    if ok(d)
        ePi0(d, :) = price_act(d, :) - pi_hat0(d, :);
    end
end

%% 分阶段残差库：按发布时刻的提前量对齐
sl = [0, 36, 72, 108];
ePi3 = nan(D, T, 4);
L_day = zeros(D, 4);
ePi0g = [ePi0; nan(1, T)];                  % 末尾平延一行备跨日取值
for j = 1:4
    for r = 1:D
        if ~ok(r) || isnan(ePi0(r,1)); continue; end
        Lr = 0;
        if sl(j) > 0
            Lr = mean(ePi0(r, 1:sl(j)));
        end
        L_day(r, j) = Lr;
        % 提前量 ℓ 对应的钟点槽（可跨入次日）
        srch = (r-1) + (sl(j) + (1:T) - 1) / T;         % 天数（0 基，含小数）
        drow = floor(srch) + 1;
        dcol = mod(sl(j) + (1:T) - 1, T) + 1;
        lin  = sub2ind([D+1, T], drow(:), dcol(:));
        ePi3(r, :, j) = ePi0g(lin).' - Lr;
    end
end

P = struct('price_act', price_act, 'pr1', pr1, 'pi_base', pi_base, ...
           'pi_hat0', pi_hat0, 'ePi0', ePi0, 'ePi3', ePi3, ...
           'L_day', L_day, 'ok', ok, 'sl', sl, 'b_hist', b_hist, ...
           'MAE', mean(abs(ePi0(ok,:)), 'all'), ...
           'RMSE', sqrt(mean(ePi0(ok,:).^2, 'all')), ...
           'MAE_base', mean(abs(ePiBase(ok,:)), 'all'));
end
