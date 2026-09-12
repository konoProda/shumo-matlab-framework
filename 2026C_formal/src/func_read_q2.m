function [price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT)
%FUNC_READ_Q2  读取问题二的输入数据
%
%   附件1：电价（每天相同，144 个值）——题面"根据附件1中的电价"
%   附件2：小区负载与光伏发电实际功率（365 天 × 144 槽）
%
%   时间列/表头行的存储类型混合，一律不读标签，按序号建轴（问题一B1/B5）。
%
%   输入  PROJ_ROOT  题目根目录
%   输出  price_v  144×1    电价 元/kWh
%         load_m   365×144  小区负载 kW
%         pv_m     365×144  光伏实际功率 kW
%         day_list 365×1    日期（程序化生成，2025-01-01 起）

T = 144;
file1 = fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx');
file2 = fullfile(PROJ_ROOT, 'data', '附件', '附件2.xlsx');

raw1 = readcell(file1, 'Sheet', 'Sheet1');
assert(size(raw1,1) == 1+T && size(raw1,2) >= 4, '附件1 维度不符（期望 145×4）');
price_v = cell2mat(raw1(2:1+T, 2));

rawL = readcell(file2, 'Sheet', '小区负载');
rawP = readcell(file2, 'Sheet', '光伏发电实际功率');
D = size(rawL, 1) - 1;
assert(D == 365 && size(rawL,2) == 1+T, '附件2 小区负载 维度不符（期望 366×145）');
assert(size(rawP,1) == 1+D && size(rawP,2) == 1+T, '附件2 光伏表 维度不符');

load_m = cell2mat(rawL(2:1+D, 2:1+T));
pv_m   = cell2mat(rawP(2:1+D, 2:1+T));

% 时间轴口径：附件列标签为时段**起始**时刻——标签 t 对应时段 [t, t+10min)。
% 每行末列标签 0:00+1（次日 0:00）对应**次日**的首槽 [0:00,0:10)，故严格跨日取值：
%   第 d 天首槽 ← 第 d-1 天末列（d>=2）；第 d 天第 k 槽（k>=2）← 第 d 天第 k-1 列。
% 第 1 天无前一日数据，取本日末列作为唯一可得值。
load_m = [[load_m(1,T); load_m(1:D-1,T)], load_m(:, 1:T-1)];
pv_m   = [[pv_m(1,T);   pv_m(1:D-1,T)],   pv_m(:, 1:T-1)];

assert(all(isfinite(load_m(:))) && all(isfinite(pv_m(:))), '附件2 含缺失或非数值');
assert(all(load_m(:) >= 0) && all(pv_m(:) >= 0), '附件2 含负值');

day_list = (datetime(2025,1,1) + days(0:D-1)).';

end
