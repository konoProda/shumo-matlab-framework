% inspect_data.m — 附件数据格式检查脚本（/prep 数据格式校验用）
% 输出各附件的 sheet 清单、尺寸、列名、前 5 行、每列缺失值计数

files = {'附件1', '附件3', '附件4'};
for k = 1:numel(files)
    f = fullfile('2023c', 'data', [files{k} '.xlsx']);
    fprintf('===== %s =====\n', files{k});
    try
        [~, sheets] = xlsfinfo(f);
        fprintf('sheets: %s\n', strjoin(sheets, ', '));
        T = readtable(f);
        fprintf('size: %d rows x %d cols\n', size(T, 1), size(T, 2));
        fprintf('vars: %s\n', strjoin(T.Properties.VariableNames, ' | '));
        disp(head(T, 5));
        miss = sum(ismissing(T), 1);
        fprintf('missing per col: ');
        fprintf('%d ', miss);
        fprintf('\n');
    catch ME
        fprintf('ERROR: %s\n', ME.message);
    end
end
