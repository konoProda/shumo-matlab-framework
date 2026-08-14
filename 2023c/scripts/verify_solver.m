% verify_solver.m — Optimization Toolbox 求解器冒烟测试（/prep 环境验证用）
fprintf('linprog:    %d\n', exist('linprog', 'file'));
fprintf('intlinprog: %d\n', exist('intlinprog', 'file'));

% LP 冒烟测试: min -x1-2x2 s.t. x1+x2<=1, x>=0 → 最优 (0,1), fval=-2
[x1, fval1] = linprog([-1; -2], [1 1], 1, [], [], [0; 0]);
fprintf('LP  冒烟: x=[%.2f, %.2f], fval=%.2f (期望 fval=-2)\n', x1(1), x1(2), fval1);

% MILP 冒烟测试: 同上但 x2 为整数 → 最优 (0,1), fval=-2
[x2, fval2] = intlinprog([-1; -2], 2, [1 1], 1, [], [], [0; 0]);
fprintf('MILP 冒烟: x=[%.1f, %.1f], fval=%.2f (期望 fval=-2)\n', x2(1), x2(2), fval2);
