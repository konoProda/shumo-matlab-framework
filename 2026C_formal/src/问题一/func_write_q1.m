function tab = func_write_q1(sol, prm, tpl_path, out_path)

% 依附件5 的 result1 模板写出结果文件，同时回带论文表1/表2 所需的数值
% sol 字段：GL / GC / C / D / E 均为 T×1（kW 或 kWh），price_v 为 T×1

T  = prm.T;
dt = prm.dt;

buy_kwh = (sol.GL + sol.GC) * dt;     % 购电量 = 外网供负载 + 外网充电
chg_kwh = sol.C * dt;
dis_kwh = sol.D * dt;

% 六个 4 小时时段（每段 24 槽）
blk_chg = zeros(6,1);
blk_dis = zeros(6,1);
for b = 1:6
    idx = (b-1)*24 + (1:24);
    blk_chg(b) = sum(chg_kwh(idx));
    blk_dis(b) = sum(dis_kwh(idx));
end

% ---- 写 result1.xlsx ----
sh1 = blank_missing(readcell(tpl_path, 'Sheet', '计划购电量'));
sh1(2:1+T, 2) = num2cell(buy_kwh);

sh2 = blank_missing(readcell(tpl_path, 'Sheet', '充放电量'));
sh2(2:7, 2) = num2cell(blk_chg);
sh2(2:7, 3) = num2cell(blk_dis);
sh2(2, 5) = num2cell(prm.E_init);
sh2(3, 5) = num2cell(sol.E(end));

writecell(sh1, out_path, 'Sheet', '计划购电量');
writecell(sh2, out_path, 'Sheet', '充放电量');

% ---- 论文表1 指定时段（槽号 = 小时×6 + 1）----
slot_of_hour = [10 12 14 16 18 20] * 6 + 1;
tab.t1_slot  = slot_of_hour(:);
tab.t1_label = arrayfun(@(h) sprintf('%d:00-%d:10', h, h), [10 12 14 16 18 20], 'UniformOutput', false).';
tab.t1_buy   = buy_kwh(slot_of_hour);
tab.t1_total = sum(buy_kwh);
tab.t1_cost  = sum(sol.price_v(:) .* (sol.GL + sol.GC)) * dt;

% ---- 论文表2 ----
tab.t2_label = {'0:00-4:00';'4:00-8:00';'8:00-12:00';'12:00-16:00';'16:00-20:00';'20:00-24:00'};
tab.t2_chg   = blk_chg;
tab.t2_dis   = blk_dis;
tab.t2_E0    = prm.E_init;
tab.t2_ET    = sol.E(end);

end

function C = blank_missing(C)
% 把 readcell 读到的空单元（missing）替换为空字符，便于 writecell 写出
for k = 1:numel(C)
    if ismissing(C{k})
        C{k} = '';
    end
end
end
