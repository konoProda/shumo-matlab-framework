function [price_v, load_p, pv_p] = func_read_q1(PROJ_ROOT)
%FUNC_READ_Q1  读取问题一的附件1 数据（电价 / 小区负载 / 光伏预测）
%
%   时间轴口径：附件标签为时段**起始**时刻——标签 t 对应时段 [t, t+10min)。
%   表中末行标签 0:00+1（次日 0:00）按日周期性与当天 0:00 相同，即当天首槽 [0:00,0:10)。
%   故数据循环右移一位：模型第 1 槽取末行，第 k 槽（k>=2）取第 k-1 行。
%   时间列存储类型混合，一律不读标签，按序号建轴。
%
%   输入  PROJ_ROOT  题目根目录
%   输出  price_v 144×1 元/kWh    load_p 144×1 kW    pv_p 144×1 kW

T = 144;
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
assert(size(raw,1) == 1+T && size(raw,2) >= 4, '附件1 维度不符（期望 145×4）');

roll_idx = [T, 1:T-1];
price_v = cell2mat(raw(2:1+T, 2));  price_v = price_v(roll_idx);
load_p  = cell2mat(raw(2:1+T, 3));  load_p  = load_p(roll_idx);
pv_p    = cell2mat(raw(2:1+T, 4));  pv_p    = pv_p(roll_idx);

assert(all(isfinite(price_v)) && all(isfinite(load_p)) && all(isfinite(pv_p)), '附件1 含缺失或非数值');

end
