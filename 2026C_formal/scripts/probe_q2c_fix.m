% probe_q2c_fix.m —— 验证"逐日独立抽样"修复与断点签名改动
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1d, PV1d] = func_read_q1(PROJ_ROOT);
D = numel(day_list);  d0 = find(day_list == datetime(2025,2,1), 1);
arch = func_resid_q2(load_m, pv_m, L1d, PV1d, 4, d0);

fprintf('\n=== 1. 逐日抽样独立性（连续 5 天的抽中历史日与相对滞后）===\n');
picks = zeros(5,4);
for k = 0:4
    dd = d0 + 100 + k;
    [~, ~, s] = func_scen_q2c(arch.eL, arch.ePV, arch.ok, dd, 4, 7, ...
                              load_m(dd:dd+6,:), pv_m(dd:dd+6,:), 28, 2026);
    picks(k+1,:) = s.picked;
    fprintf('  d=%d  抽中 %s   相对滞后 %s\n', dd, mat2str(s.picked), mat2str(dd - s.picked));
end
lags = d0 + 100 + (0:4).' - picks;
fprintf('  相对滞后在不同日之间是否变化：');
if all(all(lags == lags(1,:)))
    fprintf('否 —— 修复未生效！\n');
else
    fprintf('是（滞后集合逐日变化）—— 修复生效\n');
end

fprintf('\n=== 2. 给定日可复现 ===\n');
[~, ~, sa] = func_scen_q2c(arch.eL, arch.ePV, arch.ok, d0+100, 4, 7, ...
                           load_m(d0+100:d0+106,:), pv_m(d0+100:d0+106,:), 28, 2026);
[~, ~, sb] = func_scen_q2c(arch.eL, arch.ePV, arch.ok, d0+100, 4, 7, ...
                           load_m(d0+100:d0+106,:), pv_m(d0+100:d0+106,:), 28, 2026);
fprintf('  同一天两次调用抽中相同：%d\n', isequal(sa.picked, sb.picked));

fprintf('\n=== 3. 端到端短跑（R=7,K=4，含源码指纹与断点签名）===\n');
cfg = struct('gamma',1, 'W',28, 'min_days',5, 'Kfc',4, 'libW',28, 'seed',2026, ...
             'd_start',d0, 'use_bin',true, 'ideal',false, 'd_max',3, 'ckpt','');
r = func_roll_q2c(price_v, load_m, pv_m, day_list, L1d, PV1d, prm, 4, 7, cfg, 0);
fprintf('  前 3 天费用 %.2f 元，最大间隙 %.2e，抽中日 %s\n', ...
        sum(r.cost(1:3)), max(r.gap(1:3)), mat2str(r.picked_m(1:3,:)));
fprintf('\nPROBE_OK\n');
