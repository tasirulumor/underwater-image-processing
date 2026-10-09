function out = wb_underwater(img, cfg)
    if nargin < 2 || isempty(cfg), cfg = struct(); end
    if ~isfield(cfg,'alphaR'),      cfg.alphaR      = 1.0;  end
    if ~isfield(cfg,'alphaB'),      cfg.alphaB      = 0.0;  end
    if ~isfield(cfg,'minkowski_p'), cfg.minkowski_p = 6;    end
    if ~isfield(cfg,'clip'),        cfg.clip        = true; end

    img = im2double(img);
    if size(img,3) == 4, img = img(:,:,1:3); end
    if size(img,3) ~= 3
        error('uw:wb_underwater:badInput', 'img must be HxWx3 RGB.');
    end
    img = min(max(img, 0), 1);

    R = img(:,:,1); G = img(:,:,2); B = img(:,:,3);

    mR = mean(R(:)); mG = mean(G(:)); mB = mean(B(:));
    Rc = R + cfg.alphaR * (mG - mR) * (1 - R) .* G;
    Bc = B + cfg.alphaB * (mG - mB) * (1 - B) .* G;

    comp = cat(3, Rc, G, Bc);
    comp = min(max(comp, 0), 1);

    p = cfg.minkowski_p;
    illum = zeros(1,3);
    for c = 1:3
        ch = comp(:,:,c);
        illum(c) = mean(ch(:).^p)^(1/p);
    end
    illum = illum / (max(illum) + eps);
    gains = 1 ./ (illum + eps);

    out = zeros(size(comp));
    for c = 1:3, out(:,:,c) = comp(:,:,c) .* gains(c); end

    if cfg.clip
        out = min(max(out, 0), 1);
    end
end
