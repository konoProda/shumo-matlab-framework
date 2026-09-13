function [Lc, PVc, PIc, Lf, PVf, PIf, info] = func_scen_q4(arch3, prc, d, sl, K, ...
        Lhat_c, PVhat_c, PIC_c, Lhat_f, PVhat_f, PIC_f, lead_f, cfg)
%FUNC_SCEN_Q4  Q4 阶段 s 的三类联合情景（负荷 / 光伏 / 电价，取自同一历史日）
%
%   与问题三情景的唯一差别是**多一路电价**，抽样仍按"同一历史日"（§8 强制要求）：
%       L^(ω)  = max(0, L̂ + e^L_{r_ω})                        （钟点对齐）
%       PV^(ω) = max(0, PV̂ + ε^PV)，近端用附件3 分阶段库、远端用问题二库
%       π^(ω)  = π̂^{(d,s)} + ε^π，近端用价格分阶段库、远端用 0:00 库（钟点对齐）
%   **电价不截断为非负**（§10 与建模侧批复）：负电价在真实市场中具有经济意义，
%   程序不得因习惯而静默裁剪；实际数据中该情形不存在，但情景中会出现。
%
%   输入  arch3 问题三残差档案（含 eL / ePV / ePV3 / ok）
%         prc   func_price_q4 的输出（含 ePi0 / ePi3）
%         PIC_c / PIC_f  电价中心预测（已含当日水平项）：Tcur×1 / T×nFut
%         其余同 func_scen_q3b
%   输出  Lc Tcur×Ke、PVc Tcur×Ke、PIc Tcur×Ke；Lf/PVf/PIf T×nFut×Ke；info

Tcur = numel(Lhat_c);   T = size(Lhat_f, 1);   nFut = size(Lhat_f, 2);
stage = sl / 36 + 1;

idx = find(arch3.ok(1:d-1));
idx = idx(max(1, end-cfg.libW+1):end);
info = struct('Keff', K, 'lib_days', numel(idx), 'picked', [], 'degraded', false);
if numel(idx) < max(K, 5)
    Lc = reshape(Lhat_c, Tcur, 1);   PVc = reshape(PVhat_c, Tcur, 1);
    PIc = reshape(PIC_c, Tcur, 1);
    Lf = reshape(Lhat_f, T, nFut, 1);  PVf = reshape(PVhat_f, T, nFut, 1);
    PIf = reshape(PIC_f, T, nFut, 1);
    info.Keff = 1;  info.degraded = true;
    return;
end

rng(cfg.seed + 4*(d-1) + sl/6, 'twister');
pick = idx(randperm(numel(idx), K));

near_f = (lead_f >= 1) & (lead_f <= T);
leadc  = (sl+1:T) - sl;

Lc = zeros(Tcur, K);  PVc = zeros(Tcur, K);  PIc = zeros(Tcur, K);
Lf = zeros(T, nFut, K);  PVf = zeros(T, nFut, K);  PIf = zeros(T, nFut, K);
for w = 1:K
    r = pick(w);
    eLr = arch3.eL(r, :).';
    ePr = arch3.ePV(r, :).';
    eP3 = reshape(arch3.ePV3(r, :, stage), [T 1]);
    eIr = prc.ePi0(r, :).';                          % 钟点对齐的价格残差
    eI3 = reshape(prc.ePi3(r, :, stage), [T 1]);     % 提前量对齐的价格残差

    Lc(:, w)  = max(0, Lhat_c(:) + eLr(sl+1:T));
    PVc(:, w) = max(0, PVhat_c(:) + eP3(leadc));
    PIc(:, w) = PIC_c(:) + eI3(leadc);               % 电价不截断
    for j = 1:nFut
        Lf(:, j, w) = max(0, Lhat_f(:, j) + eLr);
        lid = min(max(lead_f(:, j), 1), T);
        fmask = ~near_f(:, j);
        ev = eP3(lid);   ev(fmask) = ePr(fmask);
        PVf(:, j, w) = max(0, PVhat_f(:, j) + ev);
        ei = eI3(lid);   ei(fmask) = eIr(fmask);
        PIf(:, j, w) = PIC_f(:, j) + ei;
    end
end
info.picked = pick(:).';

end
