% debug_pipeline.m — 分步调试脚本: 定位流水线中"下标超出范围"的具体函数与行号
% 运行: matlab -batch "run('2023c/scripts/debug_pipeline.m')"
script_full = mfilename('fullpath');
if ~startsWith(script_full, filesep)
    script_full = fullfile(pwd, script_full);
end
PROJ_ROOT = fileparts(fileparts(script_full));       % shumo/2023c
addpath(fullfile(PROJ_ROOT, 'src'));

try
    fprintf('=== step1: func_preprocess ===\n');
    prod_info = func_preprocess(PROJ_ROOT);
    fprintf('=== step2: func_q1_statistics ===\n');
    stats_q1 = func_q1_statistics(prod_info, PROJ_ROOT);
    fprintf('=== step3: func_q2_category_lp ===\n');
    r2 = func_q2_category_lp(stats_q1, prod_info, PROJ_ROOT); %#ok<NASGU>
    fprintf('=== step4: func_q3_item_milp ===\n');
    r3 = func_q3_item_milp(stats_q1, prod_info, PROJ_ROOT); %#ok<NASGU>
    disp('=== ALL STEPS OK ===');
catch ME
    fprintf('ERROR: %s\n', ME.message);
    for s = ME.stack'
        fprintf('  at %s line %d\n', s.name, s.line);
    end
end
