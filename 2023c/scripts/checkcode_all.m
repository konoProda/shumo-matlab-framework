% checkcode_all.m — 全量静态检查（/code 致命错误检查清单的执行工具）
% 检查项: 语法、未定义变量、维度隐患提示、性能提示等 (checkcode 内置规则)
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
SRC = fullfile(PROJ_ROOT, 'src');

files = {'main_vegetable', 'func_preprocess', 'func_q1_statistics', ...
         'func_q2_category_lp', 'func_q3_item_milp'};
all_ok = true;
for k = 1:numel(files)
    fprintf('===== %s.m =====\n', files{k});
    msgs = checkcode(fullfile(SRC, [files{k} '.m']));
    if isempty(msgs)
        fprintf('  OK 无问题\n');
    else
        for m = msgs'
            fprintf('  行%d: %s\n', m.line, m.message);
        end
        all_ok = false;
    end
end
fprintf('===== scripts/compare_pricing.m =====\n');
msgs = checkcode(fullfile(PROJ_ROOT, 'scripts', 'compare_pricing.m'));
if isempty(msgs)
    fprintf('  OK 无问题\n');
else
    for m = msgs'
        fprintf('  行%d: %s\n', m.line, m.message);
    end
    all_ok = false;
end
if all_ok
    fprintf('===== 全部通过 =====\n');
else
    fprintf('===== 存在警告 =====\n');
end
