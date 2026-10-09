function out = udcp_dehaze(img, cfg)
    if nargin < 2
        cfg = struct();
    end
    if ~isfield(cfg, 'patchSize'),  cfg.patchSize  = 1;    end
    if ~isfield(cfg, 'omega'),      cfg.omega      = .1;   end
    if ~isfield(cfg, 't0'),         cfg.t0         = 0.10; end
    if ~isfield(cfg, 'topPercent'), cfg.topPercent = 0.1;  end

    validateattributes(img, {'double'}, {'ndims', 3, '>=', 0, '<=', 1});
    if size(img,3) ~= 3
        error('udcp_dehaze:badInput', ...
            'img must be an H x W x 3 RGB array (got size(img,3) = %d).', size(img,3));
    end

    [H, W, ~] = size(img);
    G = img(:,:,2);
    B = img(:,:,3);

    minGB = min(G, B);
    se = ones(cfg.patchSize, cfg.patchSize);
    darkChannel = ordfilt2(minGB, 1, se, 'symmetric');

    numPixels = numel(darkChannel);
    numTop = max(1, round(cfg.topPercent * numPixels));
    [~, sortedIdx] = sort(darkChannel(:), 'descend');
    topIdx = sortedIdx(1:numTop);

    A = zeros(1, 3);
    for c = 1:3
        channel = img(:,:,c);
        A(c) = mean(channel(topIdx));
    end

    safe_A_GB = max(A(2:3), 1e-6);
    normMinGB = min(cat(3, G, B) ./ reshape(safe_A_GB, 1, 1, 2), [], 3);
    darkNorm = ordfilt2(normMinGB, 1, se, 'symmetric');

    tRaw = 1 - cfg.omega * darkNorm;
    tRaw = min(max(tRaw, 0), 1);

    grayGuide = rgb2gray(img);
    tRefined = imguidedfilter(tRaw, grayGuide, ...
        'NeighborhoodSize', [2*cfg.patchSize+1, 2*cfg.patchSize+1], ...
        'DegreeOfSmoothing', 1e-3);
    tRefined = min(max(tRefined, cfg.t0), 1);

    out = zeros(H, W, 3);
    for c = 1:3
        Ic = img(:,:,c);
        out(:,:,c) = (Ic - A(c)) ./ max(tRefined, cfg.t0) + A(c);
    end

    out = min(max(out, 0), 1);
end
