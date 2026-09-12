% probe_q2b_smoke.m —— 第三轮新增模块的冒烟验证（不跑全量，秒级）
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);

%% 1 读取：电价相位与首日首槽
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
raw1 = readcell(fullfile(PROJ_ROOT,'data','附件','附件1.xlsx'),'Sheet','Sheet1');
p_raw = cell2mat(raw1(2:145,2));
fprintf('1) 电价：模型槽1=%.4f（应=末行 %.4f），槽2=%.4f（应=首行 %.4f）\n', ...
        price_v(1), p_raw(144), price_v(2), p_raw(1));
assert(abs(price_v(1) - p_raw(144)) < 1e-12 && abs(price_v(2) - p_raw(1)) < 1e-12, '电价相位未归位');
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
assert(abs(load_m(1,1) - L1(1)) < 1e-12 && abs(pv_m(1,1) - PV1(1)) < 1e-12, '首日首槽未改用典型日');
rl = readcell(fullfile(PROJ_ROOT,'data','附件','附件2.xlsx'), 'Sheet','小区负载','Range','2:2');
v_last = cell2mat(rl(2:end));
assert(abs(load_m(2,1) - v_last(end)) < 1e-9, '第2日首槽与附件第1行末列不符');
fprintf('   首日首槽 load=%.4f（典型日）  第2日首槽 %.4f == 附件第1行末列\n', load_m(1,1), load_m(2,1));

%% 2 残差档案：一月按已知数据 → 不产生残差
D = numel(day_list);
d0 = find(day_list == datetime(2025,2,1), 1);
arch = func_resid_q2(load_m, pv_m, L1, PV1, 4, d0);
assert(isequal(size(arch.eL), [D 144]) && isequal(size(arch.ePV), [D 144]), '档案维度不符');
assert(all(~arch.ok(1:d0-1)) && all(arch.ok(d0:D)), '预报日掩码不符');
assert(all(isnan(arch.eL(1:d0-1,:)), 'all'), '一月残差未置为无效');
assert(max(arch.used_max - (1:D).') < 0, '档案存在信息泄漏');
fprintf('2) 残差档案：D=%d，预报日 %d 天（自 %s 起），一月残差已置无效\n', ...
        D, nnz(arch.ok), char(day_list(d0), 'yyyy-MM-dd'));

%% 3 校正量：2 月 1 日无历史残差 → 取 0；2 月 7 日起可用
cfg = struct('on',true,'gamma_L',1,'gamma_PV',1,'W',28,'min_days',5,'d_start',d0);
[bL0, bPV0, inf0] = func_bias_q2(arch, day_list, d0, cfg);
fprintf('3a) d=%d（%s）：窗口 %s 有效预报日 %d 天 → 校正量全 0=%d\n', ...
        d0, char(day_list(d0),'yyyy-MM-dd'), mat2str(inf0.win), inf0.n_win, ...
        all(bL0 == 0) && all(bPV0 == 0));
assert(all(bL0 == 0) && all(bPV0 == 0) && inf0.n_win == 0, '2月1日应当没有可用残差');

d7 = d0 + 6;
[bL, bPV, info] = func_bias_q2(arch, day_list, d7, cfg);
fprintf('3b) d=%d（%s）：窗口 %s 有效预报日 %d 天（同日类型 %d）\n', ...
        d7, char(day_list(d7),'yyyy-MM-dd'), mat2str(info.win), info.n_win, info.n_daytype);
fprintf('    负荷 b: 均 %.3f 范围 [%.3f, %.3f] 层级 %s\n', ...
        mean(bL), min(bL), max(bL), mat2str(unique(info.lvlL).'));
fprintf('    光伏 b: 均 %.3f 范围 [%.3f, %.3f] 夜间(1-4时)=%s\n', ...
        mean(bPV), min(bPV), max(bPV), mat2str(round(bPV(1:4).',3)));
assert(info.n_win >= 5, '窗口天数不足');
assert(all(bPV(1:4) == 0), '夜间出现非零光伏校正量');
assert(all(info.lvlL >= 1 & info.lvlL <= 3));

%% 4 短跑：一月按已知、校正自第 7 天起启用
cfg2 = struct('on',true,'gamma_L',1,'gamma_PV',1,'W',28,'min_days',5, 'd_start', 2);
res = func_roll_q2(price_v, load_m, pv_m, day_list, L1, PV1, prm, 4, 2, 'correct', 0, cfg2);
assert(max(abs(res.corr.Lraw(1,:) - load_m(1,:))) < 1e-12, '一月目标日未改用已知数据');
assert(~res.corr.on(6) && res.corr.on(7), '校正启用日判定不符（应自第 7 天起）');
assert(max(abs(res.corr.Lcor(7,:) - max(0, res.corr.Lraw(7,:) + res.corr.bL(7,floor((0:143)/6)+1)))) < 1e-9, ...
       '校正后负荷与 b 的关系不符');
fprintf('4) 短跑 8 天：1 月按已知=%d；校正第 6 天关、第 7 天开=%d；费用 %.3f 元\n', ...
        max(abs(res.corr.Lraw(1,:) - load_m(1,:))) < 1e-12, ~res.corr.on(6) && res.corr.on(7), sum(res.cost));

%% 5 旧接口兼容
[Lh, PVh, um] = func_forecast_q2(load_m, pv_m, L1, PV1, 4);
assert(isequal(size(Lh), [D 144]) && isequal(size(PVh), [D 144]) && numel(um) == D, '旧接口不兼容');
fprintf('5) 旧接口三输出调用正常（D×T=%d×%d）\n', size(Lh,1), size(Lh,2));

fprintf('\n冒烟验证全部通过\n');
