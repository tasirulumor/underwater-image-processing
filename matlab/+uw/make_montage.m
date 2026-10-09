function montage_img = make_montage(cands, pick, cfg)
    if nargin < 3, cfg = struct(); end
    if ~isfield(cfg,'tileWidth'), cfg.tileWidth = 480; end
    if ~isfield(cfg,'cols'),      cfg.cols      = 3;   end
    if ~isfield(cfg,'barH'),      cfg.barH      = 28;  end

    n = numel(cands);
    labels = cell(n+1, 1);
    tiles  = cell(n+1, 1);
    for i = 1:n
        tiles{i}  = cands(i).image;
        labels{i} = sprintf('%d) %s', i, cands(i).name);
    end
    tiles{n+1}  = pick.image;
    labels{n+1} = sprintf('CHOSEN: %s', pick.name);

    [h0, w0, ~] = size(tiles{1});
    tileHeight = max(64, round(h0 * cfg.tileWidth / max(w0, 1)));
    for i = 1:numel(tiles)
        t = tiles{i};
        if size(t, 3) == 4, t = t(:,:,1:3); end
        t = min(max(im2double(t), 0), 1);
        t = imresize(t, [tileHeight, cfg.tileWidth], 'bilinear');
        tiles{i} = addCaptionBar_(t, labels{i}, cfg.barH);
    end

    cols = cfg.cols;
    rows = ceil(numel(tiles) / cols);
    fillH = tileHeight + cfg.barH;
    while numel(tiles) < rows * cols
        tiles{end+1} = ones(fillH, cfg.tileWidth, 3);
    end
    strip_rows = cell(rows, 1);
    for r = 1:rows
        rstart = (r-1)*cols + 1;
        rend   = r * cols;
        strip_rows{r} = cat(2, tiles{rstart:rend});
    end
    montage_img = cat(1, strip_rows{:});
    montage_img = min(max(montage_img, 0), 1);
end

function out = addCaptionBar_(tile, label, barH)
    W = size(tile, 2);
    bar = zeros(barH, W, 3);
    out = [tile; bar];
    try
        out = insertText(out, [8, size(tile, 1) + 4], label, ...
            'FontSize', 14, 'BoxOpacity', 0, 'TextColor', 'white');
        if size(out, 1) ~= size(tile, 1) + barH
            out = imresize(out, [size(tile, 1) + barH, W]);
        end
    catch
    end
end
