function out = cand_udcp(img, cfg)
    if nargin < 2, cfg = struct(); end
    if ~isfield(cfg,'patchSize'),     cfg.patchSize     = 15;    end
    if ~isfield(cfg,'omega'),         cfg.omega         = 0.5;   end
    if ~isfield(cfg,'t0'),            cfg.t0            = 0.15;  end
    if ~isfield(cfg,'topPercent'),    cfg.topPercent    = 0.001; end
    if ~isfield(cfg,'overshoot_tol'), cfg.overshoot_tol = 0.18;  end

    img = im2double(img);
    if size(img,3) == 4, img = img(:,:,1:3); end
    img = min(max(img, 0), 1);

    mR = mean(mean(img(:,:,1)));
    mG = mean(mean(img(:,:,2)));
    mB = mean(mean(img(:,:,3)));
    if mG > mB * 1.25 && mG > mR * 1.25
        out = img;
        return;
    end

    dehazed = udcp_dehaze(img, cfg);
    dehazed = min(max(dehazed, 0), 1);

    mIn  = squeeze(mean(mean(img,     1), 2));
    mOut = squeeze(mean(mean(dehazed, 1), 2));
    shift = max(abs(mOut - mIn));
    if shift > cfg.overshoot_tol
        w = min(1, (shift - cfg.overshoot_tol) / cfg.overshoot_tol);
        out = (1 - w) * dehazed + w * img;
    else
        out = dehazed;
    end
    out = min(max(out, 0), 1);
end
