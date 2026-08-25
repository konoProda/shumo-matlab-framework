function [male_raw, female_raw] = load_data(data_path)
% 读取附件.xlsx 两个工作表，返回统一类型的原始表
% 输入: data_path 附件.xlsx 完整路径
% 输出: male_raw   男胎检测数据 1082×31 table
%       female_raw 女胎检测数据 605×31 table
% 列序(31列, 对应题目附录1): 1序号 2孕妇代码 3年龄 4身高 5体重 6末次月经
%   7IVF妊娠 8检测日期 9检测抽血次数 10检测孕周 11孕妇BMI 12原始读段数
%   13比对比例 14重复读段比例 15唯一比对读段数 16GC含量 17Z13 18Z18 19Z21
%   20ZX 21ZY 22Y浓度 23X浓度 24GC13 25GC18 26GC21 27过滤比例 28非整倍体
%   29怀孕次数 30生产次数 31胎儿是否健康
% 类型约定: 数值列统一为 double，文本列统一为 string（供 preprocess_data 按位置取用）
% 附加列: c32 = 怀孕次数截断编码标志（'≥3' 为 1，其余为 0），供问题三对照回归使用
% 实现说明: 用 readcell 保留单元格原始类型（附件中部分数值列混存文本型数字，
%   直接 readtable 会因类型推断把文本单元格读成 NaN），再逐列统一转换；
%   AC 列(怀孕次数)含截断编码 '≥3'，主处理映射为 3 并保留标志列

num_cols = [1, 3, 4, 5, 9, 11:27, 29, 30];   % 数值列位置
txt_cols = [2, 6, 7, 8, 10, 28, 31];         % 文本列位置

male_raw   = read_sheet(data_path, '男胎检测数据', num_cols, txt_cols);
female_raw = read_sheet(data_path, '女胎检测数据', num_cols, txt_cols);
end

function raw = read_sheet(data_path, sheet, num_cols, txt_cols)
c = readcell(data_path, 'Sheet', sheet);   % 含表头 (n+1)×31 cell
dat = c(2:end, :);
raw = table();
for k = 1:31
    if ismember(k, txt_cols)
        raw.(sprintf('c%d', k)) = string(dat(:, k));   % 缺失→<missing>，数值/日期兜底转文本
    else
        raw.(sprintf('c%d', k)) = str2double(string(dat(:, k)));   % 文本型与数值型统一转 double
    end
end
% 怀孕次数(AC列)截断编码: '≥3' 主处理映射为 3，并保留标志列
raw.c32 = double(string(dat(:, 29)) == "≥3");
raw{raw.c32 == 1, 29} = 3;
end
