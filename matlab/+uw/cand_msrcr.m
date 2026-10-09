function out = cand_msrcr(img, cfg)
    if nargin < 2, cfg = struct(); end
    if ~isfield(cfg,'sigmas'),  cfg.sigmas  = [15 80 250]; end
    if ~isfield(cfg,'alpha'),   cfg.alpha   = 100;         end
    if ~isfield(cfg,'beta'),    cfg.beta    = 40;          end
    if ~isfield(cfg,'clipPct'), cfg.clipPct = 1;           end
    img = im2double(img);
    if size(img,3) == 4, img = img(:,:,1:3); end
    out = msrcr_retinex(img, cfg);
    out = min(max(out, 0), 1);
end
