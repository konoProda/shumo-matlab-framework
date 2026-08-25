function prod_info = func_preprocess(PROJ_ROOT)
% =========================================================================
% func_preprocess.m — 数据预处理（对应建模文档第 2 节）
% 输入: PROJ_ROOT  题目根目录 shumo/2023c/
% 输出: prod_info  table, 列: 单品编码|单品名称|分类编码|分类名称|损耗率(小数)
% 产物: outputs/product_info.csv / daily_sales.csv / wholesale_price.csv
%                     / category_daily.csv
% 裁定: Q7 退货行剔除; Q8 单日缺失线性插值+连续缺失前向填充; Q9 聚合口径
% =========================================================================

OUT_DIR = fullfile(PROJ_ROOT, 'outputs');
PY_SCRIPT = fullfile(PROJ_ROOT, 'scripts', 'convert_xlsx.py');
RAW = @(name) fullfile(OUT_DIR, name);

%% 1. xlsx → CSV（数据通道 Q3-修正2: Python 流式解析, MATLAB 负责全部数学处理）
if ~all(cellfun(@(f) exist(RAW(f), 'file'), ...
        {'raw_附件1.csv', 'raw_附件2.csv', 'raw_附件3.csv', ...
         'raw_附件4_单品.csv', 'raw_附件4_小分类.csv'}))
    [st, msg] = system(['python3 ' PY_SCRIPT ' ' PROJ_ROOT]);
    assert(st == 0, '[preprocess] 转换脚本执行失败: %s', msg);
else
    fprintf('[preprocess] 原始 CSV 已存在, 跳过 xlsx 转换\n');
end

%% 2. 读取原始 CSV（显式列名与类型: 防止15位单品编码被读成数值丢失精度）
% ---- 附件1: 商品信息（单品编码|单品名称|分类编码|分类名称）----
opts = detectImportOptions(RAW('raw_附件1.csv'), 'TextType', 'string', 'Encoding', 'UTF-8');
opts.VariableNames = {'prod_code', 'prod_name', 'class_code', 'class_name'};
opts.VariableTypes = {'string', 'string', 'string', 'string'};
raw1 = readtable(RAW('raw_附件1.csv'), opts);

% ---- 附件4: 损耗率（sheet1=小分类, sheet2=单品; 值以 % 存储）----
opts = detectImportOptions(RAW('raw_附件4_单品.csv'), 'TextType', 'string', 'Encoding', 'UTF-8');
opts.VariableNames = {'prod_code', 'prod_name', 'loss_pct'};
opts.VariableTypes = {'string', 'string', 'double'};
loss_item = readtable(RAW('raw_附件4_单品.csv'), opts);

opts = detectImportOptions(RAW('raw_附件4_小分类.csv'), 'TextType', 'string', 'Encoding', 'UTF-8');
opts.VariableNames = {'class_code', 'class_name', 'class_loss_pct'};
opts.VariableTypes = {'string', 'string', 'double'};
loss_cls = readtable(RAW('raw_附件4_小分类.csv'), opts);

%% 3. 商品信息表 + 损耗率合并（建模文档第2节: %→小数, 缺失用品类平均填补）
loss_item.loss = loss_item.loss_pct / 100;            % 损耗率 % → 小数
[~, idx] = ismember(raw1.prod_code, loss_item.prod_code);
prod_info = raw1;
prod_info.loss = loss_item.loss(idx);                 % 未匹配 → NaN
cls_loss = loss_cls.class_loss_pct / 100;
[~, ci] = ismember(prod_info.class_code, loss_cls.class_code);
missing = isnan(prod_info.loss);
prod_info.loss(missing) = cls_loss(ci(missing));      % 品类平均填补
fprintf('[preprocess] 商品 %d 种, 损耗率缺失 %d 个已用品类均值填补\n', ...
        height(prod_info), sum(missing));
prod_info = sortrows(prod_info, {'class_code', 'prod_code'});
writetable(prod_info, fullfile(OUT_DIR, 'product_info.csv'), 'Encoding', 'UTF-8');
[g, cat_codes] = findgroups(prod_info.class_code);  % 品类组号(供后续缺失填补/聚合使用)
cat_codes = string(cat_codes);                     % 统一为 string 类型

%% 4. 附件2 销售流水: 日期转换 + 退货剔除(Q7) + 日-品聚合(Q9)
opts = detectImportOptions(RAW('raw_附件2.csv'), 'TextType', 'string', 'Encoding', 'UTF-8');
opts.VariableNames = {'sale_date', 'sale_time', 'prod_code', 'qty', 'unit_price', ...
                      'sale_type', 'discount'};
opts.VariableTypes = {'double', 'string', 'string', 'double', 'double', ...
                      'string', 'string'};
raw2 = readtable(RAW('raw_附件2.csv'), opts);
raw2.sale_date = datetime(raw2.sale_date, 'ConvertFrom', 'excel');  % 序列号→日期

n_return = sum(raw2.sale_type ~= "销售");
if n_return > 0
    raw2(raw2.sale_type ~= "销售", :) = [];           % Q7: 退货行剔除
    fprintf('[preprocess] 退货行剔除 %d 条\n', n_return);
end
raw2.revenue = raw2.qty .* raw2.unit_price;            % 日销售额 = 销量×单价
raw2.discount_num = double(raw2.discount == "是");     % 打折标记 0/1
% 时间段划分 (早8-13/午13-17/晚17-23)
hour = str2double(extractBefore(raw2.sale_time, ':')); % 扫码小时
raw2.qty_am = raw2.qty .* double(hour < 13);
raw2.qty_noon = raw2.qty .* double(hour >= 13 & hour < 17);
raw2.qty_pm = raw2.qty .* double(hour >= 17);

daily = groupsummary(raw2, {'sale_date', 'prod_code'}, ...
                     {'sum', 'sum', 'sum', 'sum', 'sum', 'sum'}, ...
                     {'qty', 'revenue', 'discount_num', 'qty_am', 'qty_noon', 'qty_pm'});
daily.Properties.VariableNames = {'sale_date', 'prod_code', 'n_trans', ...
                                  'qty', 'revenue', 'n_disc', 'qty_am', 'qty_noon', 'qty_pm'};
daily.avg_price = daily.revenue ./ daily.qty;          % 日均价(销量加权)
daily.has_discount = daily.n_disc > 0;
fprintf('[preprocess] 日-品聚合: %d 行 (来自 %d 条销售记录)\n', height(daily), height(raw2));

%% 5. 全网格矩阵 (公式3.2: 未售出填0) 并写出 daily_sales.csv
dates = unique(daily.sale_date);
n_date = numel(dates);
[~, iP] = ismember(daily.prod_code, prod_info.prod_code);
[~, iD] = ismember(daily.sale_date, dates);
n_prod = height(prod_info);
qty_mat   = accumarray([iP, iD], daily.qty,          [n_prod, n_date]);      % 未售出=0
rev_mat   = accumarray([iP, iD], daily.revenue,      [n_prod, n_date]);
disc_mat  = accumarray([iP, iD], daily.n_disc,       [n_prod, n_date]) > 0;
ntr_mat   = accumarray([iP, iD], daily.n_trans,      [n_prod, n_date]);      % 交易笔数
am_mat    = accumarray([iP, iD], daily.qty_am,       [n_prod, n_date]);
noon_mat  = accumarray([iP, iD], daily.qty_noon,     [n_prod, n_date]);
pm_mat    = accumarray([iP, iD], daily.qty_pm,       [n_prod, n_date]);
price_mat = rev_mat ./ qty_mat;
price_mat(qty_mat == 0) = NaN;                         % 无销售日无价格

[PD, DD] = ndgrid(prod_info.prod_code, dates);         % 长表展开
long_daily = table(PD(:), string(DD(:), 'yyyy-MM-dd'), qty_mat(:), rev_mat(:), ...
                   price_mat(:), disc_mat(:), ntr_mat(:), am_mat(:), noon_mat(:), pm_mat(:), ...
    'VariableNames', {'prod_code', 'sale_date', 'qty', 'revenue', ...
                      'avg_price', 'has_discount', 'n_trans', 'qty_am', 'qty_noon', 'qty_pm'});
writetable(long_daily, fullfile(OUT_DIR, 'daily_sales.csv'), 'Encoding', 'UTF-8');
save(fullfile(OUT_DIR, 'daily_sales.mat'), 'long_daily');   % q3 复用缓存(load约2s)

%% 6. 附件3 批发价: 同日同品取均值 + 缺失填补(Q8)
opts = detectImportOptions(RAW('raw_附件3.csv'), 'TextType', 'string', 'Encoding', 'UTF-8');
opts.VariableNames = {'w_date', 'prod_code', 'w_price'};
opts.VariableTypes = {'double', 'string', 'double'};
raw3 = readtable(RAW('raw_附件3.csv'), opts);
raw3.w_date = datetime(raw3.w_date, 'ConvertFrom', 'excel');
ws_tbl = raw3;                                     % 供 q2/q3 复用缓存(readtable约40s → load约1s)
save(fullfile(OUT_DIR, 'wholesale_price.mat'), 'ws_tbl');

wg = groupsummary(raw3, {'w_date', 'prod_code'}, 'mean', 'w_price');  % 同日同品取均价
[~, iP_w] = ismember(wg.prod_code, prod_info.prod_code);
[~, iD_w] = ismember(wg.w_date, dates);
if any(iP_w == 0)
    fprintf('[preprocess] 附件3中 %d 条批发价记录的商品不在附件1清单, 已剔除\n', sum(iP_w == 0));
end
if any(iD_w == 0)
    fprintf('[preprocess] 附件3中 %d 条批发价记录的日期不在销售日期范围内, 已剔除\n', sum(iD_w == 0));
end
keep = iP_w > 0 & iD_w > 0;                        % 仅保留可建模记录(显式剔除并计数)
w_mat = nan(n_prod, n_date);
w_mat(sub2ind([n_prod, n_date], iP_w(keep), iD_w(keep))) = wg.mean_w_price(keep);

w_mat = fillmissing(w_mat, 'linear', 2, 'EndValues', 'nearest');      % Q8: 单日缺失线性插值
w_mat = fillmissing(w_mat, 'previous', 2, 'EndValues', 'nearest');    % 连续缺失前向填充
% 整行缺失(该单品全期无批发记录): 按当日品类均值填补, 最后兜底全表均值
row_nan = all(isnan(w_mat), 2);
if any(row_nan)
    cat_mean = zeros(numel(cat_codes), n_date);
    for c = 1:numel(cat_codes)
        cat_mean(c, :) = mean(w_mat(g == c, :), 1, 'omitnan');
    end
    w_mat(row_nan, :) = cat_mean(g(row_nan), :);
    fprintf('[preprocess] %d 个单品无批发记录, 已按品类均值填补\n', sum(row_nan));
end
w_mat(isnan(w_mat)) = mean(w_mat, 'all', 'omitnan');                  % 兜底
assert(~any(isnan(w_mat), 'all'), '[preprocess] 批发价填补后仍存在 NaN, 请检查附件3');

long_w = table(PD(:), string(DD(:), 'yyyy-MM-dd'), w_mat(:), ...
    'VariableNames', {'prod_code', 'w_date', 'w_price'});
writetable(long_w, fullfile(OUT_DIR, 'wholesale_price.csv'), 'Encoding', 'UTF-8');

%% 7. 品类日聚合 category_daily.csv (Q9: 销量求和; 价格按销量加权)
cat_qty = accumarray([g(iP), iD], daily.qty, [numel(cat_codes), n_date]);      % Σ 单品销量
cat_rev = accumarray([g(iP), iD], daily.revenue, [numel(cat_codes), n_date]);
cat_price = cat_rev ./ cat_qty;
cat_price(cat_qty == 0) = NaN;

[g2, ~] = findgroups(prod_info.class_code);            % 品类平均损耗 ℓ̄_c (公式4.2)
loss_bar = splitapply(@mean, prod_info.loss, g2);

% 打折交易品类日聚合 (B3 打折数用): 打折日均价 = 打折销售额/打折销量
disc_rows = raw2(raw2.discount == "是", :);
[~, iPd] = ismember(disc_rows.prod_code, prod_info.prod_code);
[~, iDd] = ismember(disc_rows.sale_date, dates);
keep_d = iPd > 0 & iDd > 0;
cat_disc_qty = accumarray([g(iPd(keep_d)), iDd(keep_d)], disc_rows.qty(keep_d), ...
                          [numel(cat_codes), n_date]);
cat_disc_rev = accumarray([g(iPd(keep_d)), iDd(keep_d)], disc_rows.revenue(keep_d), ...
                          [numel(cat_codes), n_date]);
cat_disc_price = cat_disc_rev ./ cat_disc_qty;
cat_disc_price(cat_disc_qty == 0) = NaN;
% 品类时间段销量 (A6 用)
cat_am   = accumarray([g(iP), iD], daily.qty_am,   [numel(cat_codes), n_date]);
cat_noon = accumarray([g(iP), iD], daily.qty_noon, [numel(cat_codes), n_date]);
cat_pm   = accumarray([g(iP), iD], daily.qty_pm,   [numel(cat_codes), n_date]);

[CC, CD] = ndgrid(cat_codes, dates);   % ndgrid 第1输出=第1输入(品类码), 第2输出=第2输入(日期)
long_cat = table(CC(:), string(CD(:), 'yyyy-MM-dd'), cat_qty(:), cat_rev(:), ...
                 cat_price(:), cat_am(:), cat_noon(:), cat_pm(:), cat_disc_price(:), ...
    'VariableNames', {'class_code', 'sale_date', 'qty', 'revenue', 'avg_price', ...
                      'qty_am', 'qty_noon', 'qty_pm', 'disc_avg_price'});
[~, ci] = ismember(long_cat.class_code, cat_codes);
long_cat.loss_bar = loss_bar(ci);                      % 品类平均损耗率
long_cat.weekday = weekday(datetime(long_cat.sale_date), 'short');     % 衍生特征
long_cat.is_weekend = isweekend(datetime(long_cat.sale_date));
writetable(long_cat, fullfile(OUT_DIR, 'category_daily.csv'), 'Encoding', 'UTF-8');

fprintf('[preprocess] 完成: 商品%d种 / 品类%d个 / 天数%d\n', n_prod, numel(cat_codes), n_date);
end
