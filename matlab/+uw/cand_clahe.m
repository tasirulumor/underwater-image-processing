function out = cand_clahe(img, cfg)
    if nargin < 2, cfg = struct(); end
    img = uw.wb_underwater(img);
    if ~isfield(cfg,'ClipLimit'), cfg.ClipLimit = 0.0035; end
    if ~isfield(cfg,'NumTiles'),  cfg.NumTiles  = [8 8];  end
    if ~isfield(cfg,'Range'),     cfg.Range     = 'original'; end
    out = clahe_contrast(img, cfg);
    out = min(max(out, 0), 1);
end
