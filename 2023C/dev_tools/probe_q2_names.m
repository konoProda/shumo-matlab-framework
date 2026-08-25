% probe_q2_names.m — 探针: 复现 q2 结果表列名拼接问题（绝对路径）
sf = mfilename('fullpath');
if ~startsWith(sf, filesep), sf = fullfile(pwd, sf); end
PROJ = fileparts(fileparts(sf));
fpath = fullfile(PROJ, 'outputs', 'product_info.csv');
opts = detectImportOptions(fpath, 'TextType', 'string');
opts.VariableNames = {'prod_code', 'prod_name', 'class_code', 'class_name', 'loss'};
opts.VariableTypes = {'string', 'string', 'string', 'string', 'double'};
pi_ = readtable(fpath, opts);
[g_cat, cat_codes] = findgroups(pi_.class_code);
fprintf('findgroups groups: class=%s size=%s\n', class(cat_codes), mat2str(size(cat_codes)));
cat_codes = string(cat_codes);
fprintf('string 后: size=%s\n', mat2str(size(cat_codes)));
[~, cn] = ismember(cat_codes, pi_.class_code);
fprintf('cn: %s\n', mat2str(cn'));
cat_names_q2 = pi_.class_name(cn);
fprintf('cat_names_q2: class=%s size=%s\n', class(cat_names_q2), mat2str(size(cat_names_q2)));
disp(cat_names_q2);
x_names = strcat('x_', cat_names_q2);
p_names = strcat('p_', cat_names_q2);
col_names = ["date"; x_names; p_names];
fprintf('col_names: class=%s size=%s\n', class(col_names), mat2str(size(col_names)));
x_ct_A = rand(6, 7);
day_labels = string(1:7)';
try
    t = table(day_labels, x_ct_A', x_ct_A', 'VariableNames', col_names);
    disp('variant1(列string) OK');
catch ME
    fprintf('variant1 FAIL: %s\n', ME.message);
end
try
    t = table(day_labels, x_ct_A', x_ct_A', 'VariableNames', col_names');
    disp('variant2(行string) OK');
catch ME
    fprintf('variant2 FAIL: %s\n', ME.message);
end
try
    t = table(day_labels, x_ct_A', x_ct_A', 'VariableNames', cellstr(col_names));
    disp('variant3(cellstr) OK');
catch ME
    fprintf('variant3 FAIL: %s\n', ME.message);
end
t0 = table(day_labels, x_ct_A', x_ct_A');
fprintf('自动命名变量数: %d\n', width(t0));
fprintf('输入尺寸: day_labels=%s x_ctA''=%s\n', mat2str(size(day_labels)), mat2str(size(x_ct_A')));
