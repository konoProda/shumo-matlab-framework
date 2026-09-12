function [Lsc, PVsc, info] = func_scen_q2c(eL, ePV, okv, d, K, R, Lc, PVc, libW, seed)
%FUNC_SCEN_Q2C  生成决策日 d 的 K 个 SAA 情景（问题二第三轮，建模手 C1/C2）
%
%   抽样：从"决策日前最近 libW 个**有效预测残差日**"中**随机无放回**抽取 K 天；
%         负荷与光伏误差**成对**（同一天）、**144 槽作为整体**抽取、不逐槽打乱。
%   情景：L^(ω)_{τ,t} = max(0, 中心预测 + e^L_{s_ω,t})，光伏同式；
%         **同一情景内 R 天共用同一历史误差模板**（方案文档 §8.4 第一版约定）。
%   退化：有效残差日不足 max(K,5) 时退化为 K=1（情景 = 中心预测），并置退化标记。
%   随机性：每日独立子流 rng(seed+d)——逐日不同（独立），给定 d 完全可复现（C1 固定种子）。
%
%   输入  eL / ePV  D×T 点预测残差（NaN 表示该日无预报）
%         okv       D×1 有效预测日掩码
%         d         决策日索引
%         K         情景数（基准 4，稳定性对照 8）
%         R         视野天数
%         Lc / PVc  R×T 中心预测（第 j 行 = 第 d+j-1 天）
%         libW      残差库长度（28）
%         seed      随机种子（2026）
%   输出  Lsc / PVsc R×T×Ke（Ke = 实际情景数，退化时为 1）
%         info      Keff / lib_days / picked（抽中的历史日）/ degraded

T = size(eL, 2);
idx = find(okv(1:d-1));                       % 严格早于决策日的有效预测日
idx = idx(max(1, end-libW+1):end);            % 取最近 libW 个

need = max(K, 5);
info = struct('Keff', K, 'lib_days', numel(idx), 'picked', [], 'degraded', false, ...
              'seed', seed, 'libW', libW);

if numel(idx) < need
    Lsc = reshape(Lc, R, T, 1);
    PVsc = reshape(PVc, R, T, 1);
    info.Keff = 1;  info.degraded = true;
    return;
end

% 逐日独立子流：库长恒为 libW 时，若每天都 rng(seed) 重置，randperm 会返回**同一个置换**，
% 全年抽中的都是固定相对滞后的那几天——那是"固定的滞后模板"，不是随机抽样。
% 改用 seed+d：逐日不同（满足独立），且给定 d 完全可复现（满足 C1 的固定种子要求）。
rng(seed + d, 'twister');
pick = idx(randperm(numel(idx), K));
Lsc = zeros(R, T, K);  PVsc = zeros(R, T, K);
for w = 1:K
    Lsc(:,:,w)  = max(0, Lc  + eL(pick(w), :));     % R×T 与 1×T 隐式扩展
    PVsc(:,:,w) = max(0, PVc + ePV(pick(w), :));
end

info.picked = pick(:).';

end
