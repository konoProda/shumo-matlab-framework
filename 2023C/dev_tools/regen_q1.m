% regen_q1.m — 仅重跑问题1并重出图表（快速验证脚本）
sf = mfilename('fullpath');
if ~startsWith(sf, filesep), sf = fullfile(pwd, sf); end
PROJ = fileparts(fileparts(sf));
addpath(fullfile(PROJ, 'src'));
OUT = fullfile(PROJ, 'outputs');
opts = detectImportOptions(fullfile(OUT, 'product_info.csv'), 'TextType', 'string');
opts.VariableNames = {'prod_code', 'prod_name', 'class_code', 'class_name', 'loss'};
opts.VariableTypes = {'string', 'string', 'string', 'string', 'double'};
prod_info = readtable(fullfile(OUT, 'product_info.csv'), opts);
stats_q1 = func_q1_statistics(prod_info, PROJ, true); %#ok<NASGU>
disp('regen_q1 完成');
