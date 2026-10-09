function out = blend_score_weighted(varargin)
    if iscell(varargin{1})
        imgs   = varargin{1};
        scores = double(varargin{2}(:));
        if nargin >= 3, cfg = varargin{3}; else, cfg = struct(); end
    else
        if nargin < 4
            error('uw:blend_score_weighted:badArgs', 'Legacy call needs (A, B, sA, sB).');
        end
        imgs   = {varargin{1}, varargin{2}};
        scores = [double(varargin{3}); double(varargin{4})];
        if nargin >= 5, cfg = varargin{5}; else, cfg = struct(); end
    end

    if ~isfield(cfg,'weight_bias'), cfg.weight_bias = 1.5;  end
    if ~isfield(cfg,'weight_min'),  cfg.weight_min  = 0.05; end

    N = numel(imgs);
    if N < 1
        error('uw:blend_score_weighted:empty', 'No images supplied.');
    end
    if numel(scores) ~= N
        error('uw:blend_score_weighted:sizeMismatch', 'Got %d images but %d scores.', N, numel(scores));
    end

    for i = 1:N
        img = im2double(imgs{i});
        if size(img,3) == 4, img = img(:,:,1:3); end
        imgs{i} = min(max(img, 0), 1);
    end
    ref_size = size(imgs{1});
    for i = 2:N
        if ~isequal(size(imgs{i}), ref_size)
            imgs{i} = imresize(imgs{i}, [ref_size(1), ref_size(2)], 'bilinear');
        end
    end

    if N == 1, out = imgs{1}; return; end

    s = max(0, scores);
    if sum(s) < eps
        g = ones(N,1) / N;
    else
        g = s / sum(s);
    end
    g = g .^ cfg.weight_bias;
    g = max(g, cfg.weight_min);
    g = g / sum(g);

    W = cell(N, 1);
    for i = 1:N
        W{i} = aggregatedWeight_(imgs{i}) * g(i);
    end

    delta = 0.10;
    denom = zeros(ref_size(1), ref_size(2));
    for i = 1:N, denom = denom + W{i} + delta; end
    w = cell(N, 1);
    for i = 1:N, w{i} = (W{i} + delta) ./ denom; end

    [H, Wd, ~] = size(imgs{1});
    sizes = computeLevelSizes_(H, Wd);
    numLevels = numel(sizes);

    L = cell(N, 1);
    G = cell(N, 1);
    for i = 1:N
        L{i} = laplacianPyramid_(imgs{i}, sizes);
        G{i} = gaussianPyramid_(w{i}, sizes);
    end

    fused = cell(numLevels, 1);
    for l = 1:numLevels
        acc = zeros(size(L{1}{l}));
        for i = 1:N
            wg3 = repmat(G{i}{l}, [1 1 3]);
            acc = acc + wg3 .* L{i}{l};
        end
        fused{l} = acc;
    end

    out = fused{numLevels};
    for l = numLevels-1:-1:1
        out = imresize(out, sizes{l}, 'bilinear') + fused{l};
    end
    out = min(max(out, 0), 1);
end

function W = aggregatedWeight_(rgb)
    gray = rgb2gray(rgb);
    lap  = fspecial('laplacian', 0.2);
    WL   = abs(imfilter(gray, lap, 'replicate', 'same'));
    WSat = std(rgb, 0, 3);
    sig  = max(4, round(min(size(gray))/16));
    WS   = abs(gray - imgaussfilt(gray, sig));
    W    = WL + WSat + WS;
end

function sizes = computeLevelSizes_(H, W)
    minDim = min(H, W);
    numLevelsRequested = max(1, floor(log2(minDim / 16)) + 1);
    numLevelsRequested = min(numLevelsRequested, 8);
    maxLevels = max(1, floor(log2(minDim)) - 1);
    numLevels = max(1, min(numLevelsRequested, maxLevels));
    sizes = cell(numLevels, 1);
    sizes{1} = [H W];
    for l = 2:numLevels
        prev = sizes{l-1};
        sizes{l} = max(floor(prev/2), [4 4]);
    end
end

function G = gaussianPyramid_(im, sizes)
    numLevels = numel(sizes);
    G = cell(numLevels, 1);
    G{1} = im;
    for l = 2:numLevels
        G{l} = imresize(G{l-1}, sizes{l}, 'bilinear');
    end
end

function L = laplacianPyramid_(im, sizes)
    G = gaussianPyramid_(im, sizes);
    numLevels = numel(sizes);
    L = cell(numLevels, 1);
    for l = 1:numLevels-1
        expanded = imresize(G{l+1}, sizes{l}, 'bilinear');
        L{l} = G{l} - expanded;
    end
    L{numLevels} = G{numLevels};
end
