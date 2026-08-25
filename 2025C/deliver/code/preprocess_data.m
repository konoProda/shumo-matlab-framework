function data = preprocess_data(raw, kind, cfg)
% 孕周转换、标签构造与孕妇层聚合（P1~P6）
% 注: 命名为 preprocess_data 以避免与 Computer Vision Toolbox 的 preprocess 重名
% 输入: raw  load_data 返回的 31 列 table（或同类型约定的探针数据）
%       kind 'male' 或 'female'
%       cfg  主程序参数结构体（使用 thr_y）
% 输出: data 结构体
%   male:   rec  记录层(1082行): subj_id/age/height/weight/ivf_str/gest_week/bmi/
%              y_conc/z_y/gc/raw_reads/map_rate/dup_rate/unique_reads/filter_ratio/
%              ab_str/gravidity/parity/healthy_str/is_reach/d_iui/d_ivf
%           subj 孕妇层(267行): subj_id/n_det/bmi_mean/age/gravidity/parity/
%              d_iui/d_ivf/first_reach_time
%   female: rec  记录层(605行): subj_id/age/bmi/gest_week/z13/z18/z21/zx/gc/
%              gc13/gc18/gc21/raw_reads/map_rate/dup_rate/unique_reads/filter_ratio/
%              ab_str/abn_label/abn_t13/abn_t18/abn_t21/gravidity/parity/healthy_str

switch kind
    case 'male'
        data = prep_male(raw, cfg);
    case 'female'
        data = prep_female(raw, cfg);
    otherwise
        error('kind 必须为 male 或 female');
end
end

function data = prep_male(raw, cfg)
n_rec = size(raw, 1);
n_exp = 1082;
if isfield(cfg, 'n_rec_male'), n_exp = cfg.n_rec_male; end   % 探针数据可覆盖期望值
assert(n_rec == n_exp, '男胎记录数应为%d，实际%d', n_exp, n_rec);

rec = table();
rec.subj_id      = raw{:, 2};
rec.age          = raw{:, 3};
rec.height       = raw{:, 4};
rec.weight       = raw{:, 5};
rec.ivf_str      = raw{:, 7};
rec.gest_week    = parse_gestweek(raw{:, 10});   % P1
rec.bmi          = raw{:, 11};
rec.y_conc       = raw{:, 22};
rec.z_y          = raw{:, 21};
rec.gc           = raw{:, 16};
rec.raw_reads    = raw{:, 12};
rec.map_rate     = raw{:, 13};
rec.dup_rate     = raw{:, 14};
rec.unique_reads = raw{:, 15};
rec.filter_ratio = raw{:, 27};
rec.ab_str       = raw{:, 28};
rec.gravidity    = raw{:, 29};
if size(raw, 2) >= 32
    rec.grav_ge3 = raw{:, 32};   % 怀孕次数截断编码标志（探针/测试构造表无此列时置零）
else
    rec.grav_ge3 = zeros(n_rec, 1);
end
rec.parity       = raw{:, 30};
rec.healthy_str  = raw{:, 31};
rec.is_reach     = double(rec.y_conc >= cfg.thr_y);   % P2
rec.d_iui        = double(contains(rec.ivf_str, 'IUI'));
rec.d_ivf        = double(contains(rec.ivf_str, 'IVF'));

% 孕妇层聚合（P4/P5）
[subj_ids, ~, grp] = unique(rec.subj_id, 'stable');
n_subj = numel(subj_ids);
n_exp_s = 267;
if isfield(cfg, 'n_subj_male'), n_exp_s = cfg.n_subj_male; end   % 探针数据可覆盖期望值
assert(n_subj == n_exp_s, '男胎孕妇数应为%d，实际%d', n_exp_s, n_subj);
subj = table();
subj.subj_id   = subj_ids;
subj.n_det     = splitapply(@numel, grp, grp);
subj.bmi_mean  = splitapply(@(x) mean(x, 'omitnan'), rec.bmi, grp);   % P4
subj.age       = splitapply(@first_finite, rec.age, grp);
subj.gravidity = splitapply(@first_finite, rec.gravidity, grp);
subj.parity    = splitapply(@first_finite, rec.parity, grp);
subj.d_iui     = splitapply(@first_finite, rec.d_iui, grp);
subj.d_ivf     = splitapply(@first_finite, rec.d_ivf, grp);
subj.first_reach_time = splitapply(@first_reach, rec.gest_week, rec.is_reach, grp);  % P5

data = struct('rec', rec, 'subj', subj);
end

function data = prep_female(raw, cfg)
n_rec = size(raw, 1);
n_exp = 605;
if isfield(cfg, 'n_rec_female'), n_exp = cfg.n_rec_female; end   % 探针数据可覆盖期望值
assert(n_rec == n_exp, '女胎记录数应为%d，实际%d', n_exp, n_rec);

rec = table();
rec.subj_id      = raw{:, 2};
rec.age          = raw{:, 3};
rec.gest_week    = parse_gestweek(raw{:, 10});   % P1
rec.bmi          = raw{:, 11};                   % 缺失 1 条保留为 NaN（P6）
rec.gc           = raw{:, 16};
rec.z13          = raw{:, 17};
rec.z18          = raw{:, 18};
rec.z21          = raw{:, 19};
rec.zx           = raw{:, 20};
rec.gc13         = raw{:, 24};
rec.gc18         = raw{:, 25};
rec.gc21         = raw{:, 26};
rec.raw_reads    = raw{:, 12};
rec.map_rate     = raw{:, 13};
rec.dup_rate     = raw{:, 14};
rec.unique_reads = raw{:, 15};
rec.filter_ratio = raw{:, 27};
rec.ab_str       = raw{:, 28};
rec.gravidity    = raw{:, 29};
if size(raw, 2) >= 32
    rec.grav_ge3 = raw{:, 32};   % 怀孕次数截断编码标志（探针/测试构造表无此列时置零）
else
    rec.grav_ge3 = zeros(n_rec, 1);
end
rec.parity       = raw{:, 30};
rec.healthy_str  = raw{:, 31};

% 女胎异常标签（P3）
rec.abn_label = double(~ismissing(rec.ab_str) & rec.ab_str ~= "");
rec.abn_t13 = double(contains(rec.ab_str, 'T13'));
rec.abn_t18 = double(contains(rec.ab_str, 'T18'));
rec.abn_t21 = double(contains(rec.ab_str, 'T21'));

[subj_ids, ~, ~] = unique(rec.subj_id, 'stable');
n_exp_s = 147;
if isfield(cfg, 'n_subj_female'), n_exp_s = cfg.n_subj_female; end   % 探针数据可覆盖期望值
assert(numel(subj_ids) == n_exp_s, '女胎孕妇数应为%d，实际%d', n_exp_s, numel(subj_ids));

data = struct('rec', rec);
end

function t = parse_gestweek(str_vec)
% P1: '11w+6' -> 11 + 6/7，兼容大小写 w/W；格式异常或缺失置 NaN
t = nan(numel(str_vec), 1);
for i = 1:numel(str_vec)
    s = str_vec(i);
    if ismissing(s), continue; end
    tok = regexp(char(s), '^(\d+)w\+?(\d*)$', 'tokens', 'once', 'ignorecase');
    if isempty(tok), continue; end
    w = str2double(tok{1});
    d = str2double(tok{2});
    if isempty(d) || isnan(d), d = 0; end
    t(i) = w + d / 7;
end
end

function t1 = first_reach(t, r)
% P5: 按孕周升序取首次达标检测孕周，均未达标返回 NaN
[t_s, ord] = sort(t);
r_s = r(ord);
idx = find(r_s == 1, 1, 'first');
if isempty(idx), t1 = nan; else, t1 = t_s(idx); end
end

function v = first_finite(x)
% 孕妇层固定协变量: 取组内首个非 NaN 值（防个别记录缺失传播到孕妇层）
idx = find(isfinite(x), 1, 'first');
if isempty(idx), v = nan; else, v = x(idx); end
end
