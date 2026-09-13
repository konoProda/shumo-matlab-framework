function [price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT)
%FUNC_READ_Q2  读取问题二的输入数据
%
%   附件1：电价 / 小区负载 / 光伏预测功率（每天相同，144 槽）
%   附件2：小区负载与光伏发电实际功率（365 天 × 144 槽）
%
%   时间轴口径（起始标签；2026-09-12 二次修订，修电价相位与首日首槽两处）：
%     标签 t 对应时段 [ t, t+10min )；末位标签 0:00+1（次日 0:00）归属**次日**首槽。
%     - 附件2 逐日表：第 d 天首槽 [0:00,0:10) 取第 d-1 天末列（d>=2）；
%       第 d 天第 k 槽（k>=2）取第 d 天第 k-1 列。
%     - 附件1 日周期表：末行 0:00+1 按日周期性归位到本日首槽，整表循环右移一位
%       （电价、典型日负载/光伏三列同此处理）。
%     - 首日（2025-01-01）首槽无前一日数据：取附件1 典型日的首槽值填补
%       （冷启动假设）；不得取本日末列——那是次日的实测值。
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
roll    = [T, 1:T-1];
price_v = cell2mat(raw1(2:1+T, 2));  price_v = price_v(roll);
L1      = cell2mat(raw1(2:1+T, 3));  L1      = L1(roll);
PV1     = cell2mat(raw1(2:1+T, 4));  PV1     = PV1(roll);

rawL = readcell(file2, 'Sheet', '小区负载');
rawP = readcell(file2, 'Sheet', '光伏发电实际功率');
D = size(rawL, 1) - 1;
assert(D == 365 && size(rawL,2) == 1+T, '附件2 小区负载 维度不符（期望 366×145）');
assert(size(rawP,1) == 1+D && size(rawP,2) == 1+T, '附件2 光伏表 维度不符');

load_m = cell2mat(rawL(2:1+D, 2:1+T));
pv_m   = cell2mat(rawP(2:1+D, 2:1+T));

load_m = [[load_m(1,T); load_m(1:D-1,T)], load_m(:, 1:T-1)];
pv_m   = [[pv_m(1,T);   pv_m(1:D-1,T)],   pv_m(:, 1:T-1)];

load_m(1,1) = L1(1);          % 首日首槽缺失，用典型日首槽补
pv_m(1,1)   = PV1(1);

assert(all(isfinite(load_m(:))) && all(isfinite(pv_m(:))), '附件2 含缺失或非数值');
assert(all(load_m(:) >= 0) && all(pv_m(:) >= 0), '附件2 含负值');

day_list = (datetime(2025,1,1) + days(0:D-1)).';

end
