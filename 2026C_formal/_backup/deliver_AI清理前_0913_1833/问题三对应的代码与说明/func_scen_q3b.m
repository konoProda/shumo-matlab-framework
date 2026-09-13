function [Lc, PVc, Lf, PVf, info] = func_scen_q3b(arch3, d, sl, K, ...
        Lhat_c, PVhat_c, Lhat_f, PVhat_f, lead_f, cfg)
%FUNC_SCEN_Q3B  生成阶段 s 的 K 个联合情景（负荷 / 光伏，来源同一历史日）
%
%   抽样：从决策日前"最近 libW 个有效残差日"中随机无放回抽 K 天（裁决 C12/D4）。
%   情景：负荷   L^(ω) = max(0, L̂ + e^L_{r_ω})；
%         光伏   PV^(ω) = max(0, PV̂ + ε)，其中
%                 近端（自发布时刻起提前量 ℓ ≤ 144）：ε = e^{PV,s}_{r_ω,ℓ}（附件3 分阶段库）
%                 远端（ℓ > 144）            ：ε = e^{PV,Q2}_{r_ω,t}（问题二库，按钟点）
%         三处中心预测同属一条视野，故同一情景的负荷与光伏误差**来自同一历史日**。
%   退化：有效残差日不足 max(K,5) 时退化为 K=1（情景 = 中心预测），置退化标记。
%   随机性：按 (d,sl) 构造独立固定子流 rng(seed + 4(d−1) + sl/6)：
%           同日同阶段完全可复现；不同日、不同阶段相互独立（裁决 C12/D6）。
%
%   输入  arch3   func_resid_q3b 的档案（含 eL / ePV / ePV3 / ok）
%         d       决策日索引；sl 当天已执行槽数；K 情景数
%         Lhat_c / PVhat_c   Tcur×1 当天尚未执行时段的中心预测
%         Lhat_f / PVhat_f   T×nFut 未来日中心预测
%         lead_f             T×nFut 未来日各槽相对发布时刻的提前量
%         cfg      含 seed / libW
%   输出  Lc Tcur×Ke、PVc Tcur×Ke、Lf T×nFut×Ke、PVf T×nFut×Ke
%         info  Keff / lib_days / picked / degraded

Tcur = numel(Lhat_c);
nFut = size(Lhat_f, 2);
T = size(Lhat_f, 1);
stage = sl / 36 + 1;                         % 1..4（sl 是槽数：0/36/72/108）

idx = find(arch3.ok(1:d-1));                 % 严格早于决策日的有效预测日
idx = idx(max(1, end-cfg.libW+1):end);       % 取最近 libW 个

info = struct('Keff', K, 'lib_days', numel(idx), 'picked', [], 'degraded', false);
if numel(idx) < max(K, 5)
    Lc = reshape(Lhat_c, Tcur, 1);   PVc = reshape(PVhat_c, Tcur, 1);
    Lf = reshape(Lhat_f, T, nFut, 1);  PVf = reshape(PVhat_f, T, nFut, 1);
    info.Keff = 1;  info.degraded = true;
    return;
end

% 逐 (日,阶段) 独立子流：同一天同一阶段重复运行结果完全一致，
% 而不同日 / 不同阶段互不相同（若每天都重置到同一种子，抽样会退化为固定模板）。
rng(cfg.seed + 4*(d-1) + sl/6, 'twister');
pick = idx(randperm(numel(idx), K));

near_f = (lead_f >= 1) & (lead_f <= T);      % 未来日哪些槽落在近端 24 h 内
leadc  = (sl+1:T) - sl;                      % 当天尚未执行时段的提前量（1..Tcur）

% 一律按**列向量**组织：MATLAB 中"用行索引去取列向量"返回的仍是列向量，
% 一旦与行向量相加就会静默广播成矩阵。全部取列可彻底避开这一类朝向陷阱。
Lc = zeros(Tcur, K);  PVc = zeros(Tcur, K);
Lf = zeros(T, nFut, K);  PVf = zeros(T, nFut, K);
for w = 1:K
    r = pick(w);
    eLr = arch3.eL(r, :).';                          % T×1
    ePr = arch3.ePV(r, :).';                         % T×1，按钟点
    eP3 = reshape(arch3.ePV3(r, :, stage), [T 1]);   % T×1，按提前量（已按发布时刻对齐）

    Lc(:, w) = max(0, Lhat_c(:) + eLr(sl+1:T));
    PVc(:, w) = max(0, PVhat_c(:) + eP3(leadc));
    for j = 1:nFut
        Lf(:, j, w) = max(0, Lhat_f(:, j) + eLr);
        % 提前量超过 24 h（lead > T）的槽属于远端，只作占位取值、随后被覆盖，
        % 故先钳到合法下标再查表，避免越界报错
        lid = min(max(lead_f(:, j), 1), T);
        epsv = eP3(lid);                             % T×1
        fmask = ~near_f(:, j);
        epsv(fmask) = ePr(fmask);
        PVf(:, j, w) = max(0, PVhat_f(:, j) + epsv);
    end
end
info.picked = pick(:).';

end
