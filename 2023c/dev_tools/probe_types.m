% probe_types.m — 类型探针: 复现 func_preprocess 141-152 行的类型问题
cc_in = ["1011010101"; "1011010201"; "1011010402"];
[g, cat_codes] = findgroups(cc_in);
fprintf('findgroups 返回 groups 类型: %s\n', class(cat_codes));
cat_codes = string(cat_codes);
fprintf('string() 转换后类型: %s\n', class(cat_codes));
dates = datetime(2023, 7, 1) + caldays(0:4);
fprintf('dates 类型: %s\n', class(dates));
[CD, CG] = ndgrid(cat_codes, dates);
fprintf('ndgrid 后 CD 类型: %s, CG 类型: %s\n', class(CD), class(CG));
s = string(CD(:), 'yyyy-MM-dd');
fprintf('string(CD(:), fmt) 成功, 样例: %s\n', s(1));
