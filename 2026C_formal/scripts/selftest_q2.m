% selftest_q2.m —— 静态检查与装配尺寸自检（组内产物，不交付）
clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

fs = {'src/func_build_q2.m','src/func_read_q2.m','src/func_check_q2.m', ...
      'src/func_write_q2.m','src/main_q2.m','src/main_q2_year.m','scripts/probe_q2_toy.m'};
fprintf('---- checkcode ----\n');
for k = 1:numel(fs)
    m = checkcode(fs{k}, '-struct');
    if isempty(m)
        fprintf('  [OK] %s\n', fs{k});
    else
        fprintf('  [!!] %s\n', fs{k});
        for j = 1:numel(m)
            fprintf('       L%d: %s\n', m(j).line, m(j).message);
        end
    end
end

fprintf('\n---- 装配尺寸自检 ----\n');
prm = struct('T',144,'dt',1/6,'eta_ch',0.9,'eta_dis',0.9,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = 144;

[f, ic, A, b, Aeq, beq, lb, ub, aux] = ...
    func_build_q2(rand(T,1)*1.4, rand(T,1)*4000, rand(T,1)*8000, 6000, prm, true);
fprintf('  单日 MILP : n=%d  intcon=%d  Aeq=[%d %d]  A=[%d %d]  nnz(Aeq)=%d  nnz(A)=%d\n', ...
        numel(f), numel(ic), size(Aeq), size(A), nnz(Aeq), nnz(A));

[f2, ic2, ~, ~, Aeq2, ~, lb2, ub2] = ...
    func_build_q2(rand(T,1), rand(T,1)*4000, rand(T,1)*8000, 6000, prm, false);
fprintf('  单日 LP   : n=%d  intcon=%d  Aeq=[%d %d]\n', numel(f2), numel(ic2), size(Aeq2));

assert(numel(f) == 1440 && numel(ic) == 144 && isequal(size(Aeq), [576 1440]) && isequal(size(A), [288 1440]));
assert(numel(f2) == 1296 && isempty(ic2) && isequal(size(Aeq2), [576 1296]));
assert(all(lb <= ub) && all(isfinite(lb)));
assert(numel(b) == size(A,1) && numel(beq) == size(Aeq,1));
assert(all(isfinite(ub(aux.idx.C : aux.idx.C+T-1))) && all(isfinite(ub2(aux.idx.C : aux.idx.C+T-1))));

% 全年规模
D = 365; nSy = D * T;
[fy, ~, Ay, by, Aeqy, ~, ~, ~, auxy] = ...
    func_build_q2(rand(nSy,1), rand(nSy,1)*4000, rand(nSy,1)*8000, 6000, prm, false);
fprintf('  全年 LP   : n=%d  Aeq=[%d %d]  nnz=%d  (%.1f MB 三元组)\n', ...
        numel(fy), size(Aeqy), nnz(Aeqy), nnz(Aeqy)*16/1e6);
assert(numel(fy) == 9*nSy && isequal(size(Aeqy), [4*nSy 9*nSy]));
assert(numel(by) == 0 && size(Ay,1) == 0);
fprintf('  断言全部通过\n');
