% probe_q3_lb.m — 探针: 定位 sat_lb>0 时"A列数不等于f"的出错行
sf = mfilename('fullpath');
if ~startsWith(sf, filesep), sf = fullfile(pwd, sf); end
PROJ = fileparts(fileparts(sf));
addpath(fullfile(PROJ, 'src'));
OUT = fullfile(PROJ, 'outputs');
opts = detectImportOptions(fullfile(OUT, 'product_info.csv'), 'TextType', 'string');
opts.VariableNames = {'prod_code', 'prod_name', 'class_code', 'class_name', 'loss'};
opts.VariableTypes = {'string', 'string', 'string', 'string', 'double'};
prod_info = readtable(fullfile(OUT, 'product_info.csv'), opts);
stats_q1 = func_q1_statistics(prod_info, PROJ, false);
try
    r = func_q3_item_milp(stats_q1, prod_info, PROJ, false, 0.5); %#ok<NASGU>
    disp('sat_lb=0.1 OK');
catch ME
    fprintf('ERROR: %s\n', ME.message);
    for s = ME.stack'
        fprintf('  at %s line %d\n', s.name, s.line);
    end
end
