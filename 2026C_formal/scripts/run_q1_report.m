% run_q1_report.m — 问题一正式运行驱动（组内产物，不交付）
% 清空内存 → 跑 main_q1 → 记录耗时与内存 → 落盘 final_results_q1.mat

tic;
run(fullfile(fileparts(mfilename('fullpath')), '..', 'src', 'main_q1.m'));
t_total = toc;

w_sol = whos('sol');
w_prm = whos('prm');

out_path = fullfile(PROJ_ROOT, 'outputs', 'final_results_q1.mat');
save(out_path, 'sol', 'prm', 'Z', 'rep', 'output', 'exitflag', 'tab', 't_total');

fprintf('\n=== 正式运行记录 ===\n');
fprintf('  总耗时     %.2f s\n', t_total);
fprintf('  解变量内存 %.3f MB\n', w_sol.bytes / 1e6);
fprintf('  参数内存   %.3f MB\n', w_prm.bytes / 1e6);
fprintf('  结果文件   %s\n', out_path);
