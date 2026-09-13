function arch = func_resid_q2(load_m, pv_m, L1, PV1, K, d_start)
%FUNC_RESID_Q2  建立"原始预测残差"档案（问题二 预测层偏差校正 第一步）
%
%   对每个已完成历史日 s，取其【当日 0:00 实际发布/生成的原始预测】X̂⁰(s,t|s)，与实际作差：
%       e^X(s,t) = Xact(s,t) − X̂⁰(s,t|s)
%   逐日模式的第 s 行与"决策日 = 目标日"的地平线模式首行完全一致（同一套回溯规则、
%   同一截止日），故直接调用逐日模式一次算完全年，滚动循环内不再重算。
%
%   档案一律存**原始**预测的残差；校正后的残差不得回写此处（否则估计对象漂移）。
%
%   报告窗口之前（一月）按已知数据处理，**不产生预报也就不产生残差**：
%   这些行置为 NaN 并由 arch.ok 标记为无效，不进入任何估计窗口。
%
%   输入  load_m / pv_m  D×T 实际值；L1 / PV1 附件1 典型日曲线；K 同星期回溯周数
%         d_start        首个"需要预测"的日子（= 报告窗口首日）；省略则全日可用
%   输出  arch.L0 / PV0    D×T 原始预测
%         arch.eL / ePV    D×T 残差（实际 − 原始预测）；d_start 之前为 NaN
%         arch.Lact / PVact D×T 实际值（夜间保护与诊断用）
%         arch.fb          D×1 该日预测是否走了冷启动/扩展均值回退
%         arch.used_max    D×1 该日预测引用的最晚历史日（信息泄漏自检）
%         arch.ok          D×1 该日是否真的发过预报（估计窗口只允许取 true 的行）

if nargin < 6 || isempty(d_start); d_start = 1; end
D = size(load_m, 1);
assert(d_start >= 1 && d_start <= D + 1, '首个预测日越界');

[L0, PV0, um, fb] = func_forecast_q2(load_m, pv_m, L1, PV1, K);
eL = load_m - L0;   ePV = pv_m - PV0;

ok = false(D, 1);
if d_start <= D
    ok(d_start:D) = true;
end
eL(~ok, :) = NaN;   ePV(~ok, :) = NaN;

arch = struct( ...
    'L0',       L0, ...
    'PV0',      PV0, ...
    'eL',       eL, ...
    'ePV',      ePV, ...
    'Lact',     load_m, ...
    'PVact',    pv_m, ...
    'fb',       fb, ...
    'ok',       ok, ...
    'used_max', um, ...
    'K', K);

end
