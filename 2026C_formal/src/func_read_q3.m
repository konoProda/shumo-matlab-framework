function [price_v, load_m, pv_m, day_list, fc3] = func_read_q3(PROJ_ROOT)
%FUNC_READ_Q3  读取问题三的输入数据
%
%   附件1：电价（每天相同，144 个值）
%   附件2：小区负载与光伏发电实际功率（365 天 × 144 槽）——读法与问题二完全一致
%   附件3：每天 0:00 / 6:00 / 12:00 / 18:00 发布的未来 24 小时整点光伏预报
%
%   附件3 的"预报k小时"= 自发布时刻起第 k 个整点区间 [ τ+(k-1)h, τ+kh )，
%   已由夜间全零、日出跃变配对、支撑集三组判据钉死（见输出日志 §2）。
%   日期只写在每日首行，故按行号整除 4 定位，不按日期字符串匹配。
%
%   输入  PROJ_ROOT  题目根目录
%   输出  price_v  144×1      电价 元/kWh
%         load_m   365×144    小区负载 kW
%         pv_m     365×144    光伏实际功率 kW
%         day_list 365×1      日期（2025-01-01 起）
%         fc3      365×4×24   光伏预报 kW；第 2 维 = 发布时刻（0/6/12/18 时），第 3 维 = 预报 1..24 小时

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);

D = numel(day_list);
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件3.xlsx'), 'Sheet', 'Sheet1');
assert(size(raw, 2) == 2 + 24, '附件3 列数不符（期望 26 列）');
assert(size(raw, 1) == 1 + 4*D, '附件3 行数不符（期望 %d 行）', 1 + 4*D);

fc3 = zeros(D, 4, 24);
for j = 1:4
    blk = raw(2 + (0:D-1)*4 + (j-1), 3:26);      % 取第 j 个发布时刻的整块
    fc3(:, j, :) = reshape(cell2mat(blk), [D 1 24]);
end

assert(all(isfinite(fc3(:))) && all(fc3(:) >= 0), '附件3 含缺失、非数值或负值');
assert(max(fc3(:)) > 0, '附件3 读取异常：全零');

end
