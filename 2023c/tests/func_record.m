function [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, name, ok, exp_str, act_str)
% func_record.m — 测试记录辅助函数: 打印 PASS/FAIL 并更新计数与失败清单
% 输入: n_pass/n_fail 当前计数; fail_list 失败项 cell; name 测试项名;
%       ok 是否通过; exp_str/act_str 预期与实际(字符串)
% 输出: 更新后的计数与失败清单
if ok
    n_pass = n_pass + 1;
    fprintf('[PASS] %s\n', name);
else
    n_fail = n_fail + 1;
    fail_list{end + 1} = sprintf('%s | 预期: %s | 实际: %s', name, exp_str, act_str); %#ok<AGROW>
    fprintf('[FAIL] %s\n  预期: %s\n  实际: %s\n', name, exp_str, act_str);
end
end
