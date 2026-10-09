function out = clahe_contrast(img, cfg)
    if nargin < 2
        cfg = struct();
    end
    if ~isfield(cfg, 'ClipLimit'), cfg.ClipLimit = 0.0025;  end
    if ~isfield(cfg, 'NumTiles'),  cfg.NumTiles  = [8 8]; end
    if ~isfield(cfg, 'Range'),     cfg.Range     = 'original'; end

    validateattributes(img, {'double'}, {'ndims', 3, '>=', 0, '<=', 1});
    if size(img,3) ~= 3
        error('clahe_contrast:badInput', ...
            'img must be an H x W x 3 RGB array (got size(img,3) = %d).', size(img,3));
    end

    labImg = rgb2lab(img);
    L = labImg(:,:,1);
    a = labImg(:,:,2);
    b = labImg(:,:,3);

    L01 = L / 100;
    L01_eq = adapthisteq(L01, ...
        'ClipLimit', cfg.ClipLimit, ...
        'NumTiles',  cfg.NumTiles, ...
        'Range',     cfg.Range);
    L_eq = L01_eq * 100;

    labOut = cat(3, L_eq, a, b);
    out = lab2rgb(labOut);
    out = min(max(out, 0), 1);
end
