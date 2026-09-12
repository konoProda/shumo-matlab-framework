% write_q2b_deliver.m —— 从选定配置的结果写出候选交付件（不覆盖现有 result2.xlsx）
%
% 建模方案 §8.3：候选结果以独立标识保存，验收并记录选定配置后再生成正式交付副本。
% 故本脚本写出 outputs/result2_<配置>.xlsx，供选定后再复制为 result2.xlsx。
%
% 用法：改 cfg_name 或直接 `write_q2b_deliver('B3')`

cfg_name = 'B3';
if exist('cfg_name', 'var') && ischar(cfg_name); else; cfg_name = 'B3'; end

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

S = load(fullfile(PROJ_ROOT, 'outputs', sprintf('final_results_q2b_%s.mat', cfg_name)));
[price_v, ~, ~, day_list] = func_read_q2(PROJ_ROOT);
D  = numel(day_list);
ri = (find(day_list == datetime(2025,2,1)):D).';

resw = struct('buy_m', S.res.buy_m, 'em_m', S.res.em_m, 'chg_m', S.res.chg_m, ...
              'dis_m', S.res.dis_m, 'curt_m', S.res.curt_m, 'Eend_m', S.res.Eend_m, ...
              'E0_m', S.res.E0_m, 'price_v', price_v, 'day_list', day_list, ...
              'rep_idx', ri, 'kappa_em', S.prm.kappa_em);

out_path = fullfile(PROJ_ROOT, 'outputs', sprintf('result2_%s.xlsx', cfg_name));
func_write_q2(resw, S.prm, ...
    fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result2.xlsx'), out_path);

Z = sum(S.res.cost(ri));
fprintf('候选交付件已写出：outputs/result2_%s.xlsx（报送窗口费用 %.2f 元）\n', cfg_name, Z);
fprintf('  → 待建模手确定配置后，复制为 outputs/result2.xlsx（正式交付件）\n');
