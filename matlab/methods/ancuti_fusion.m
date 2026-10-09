function [out, Wa, Wb] = ancuti_fusion(candidateA, candidateB, cfg)
    if nargin < 3 || isempty(cfg)
        cfg = struct();
    end

    if ~isa(candidateA, 'double') || ~isa(candidateB, 'double')
        error('ancuti_fusion:badInput', 'candidateA/candidateB must both be double arrays in [0,1].');
    end
    if ~isequal(size(candidateA), size(candidateB))
        error('ancuti_fusion:badInput', ...
            'candidateA and candidateB must be the same size (got %s vs %s).', ...
            mat2str(size(candidateA)), mat2str(size(candidateB)));
    end
    if ndims(candidateA) ~= 3 || size(candidateA,3) ~= 3
        error('ancuti_fusion:badInput', ...
            'candidateA/candidateB must be H x W x 3 RGB arrays (got size %s).', mat2str(size(candidateA)));
    end
    candidateA = min(max(candidateA, 0), 1);
    candidateB = min(max(candidateB, 0), 1);

    [H, W, ~] = size(candidateA);
    cfg = fillDefaults(cfg, H, W);

    WA_agg = aggregatedWeight(candidateA, cfg);
    WB_agg = aggregatedWeight(candidateB, cfg);

    delta = cfg.weightRegularization;
    denom = WA_agg + WB_agg + 2*delta;
    Wa = (WA_agg + delta) ./ denom;
    Wb = (WB_agg + delta) ./ denom;

    sizes = computeLevelSizes(H, W, cfg.numLevels);
    numLevels = numel(sizes);

    La = genLaplacianPyramid(candidateA, sizes);
    Lb = genLaplacianPyramid(candidateB, sizes);
    Ga = genGaussianPyramid(Wa, sizes);
    Gb = genGaussianPyramid(Wb, sizes);

    Fused = cell(numLevels, 1);
    for l = 1:numLevels
        nCh = size(La{l}, 3);
        Ga3 = repmat(Ga{l}, [1 1 nCh]);
        Gb3 = repmat(Gb{l}, [1 1 nCh]);
        Fused{l} = Ga3 .* La{l} + Gb3 .* Lb{l};
    end

    out = collapsePyramid(Fused, sizes);
    out = min(max(out, 0), 1);
end

function cfg = fillDefaults(cfg, H, W)
    defaults.laplacianAlpha       = 0.2;
    defaults.saliencySigma        = max(4, round(min(H,W)/16));
    defaults.weightRegularization = 0.1;
    defaults.numLevels            = [];
    fn = fieldnames(defaults);
    for i = 1:numel(fn)
        if ~isfield(cfg, fn{i}) || isempty(cfg.(fn{i}))
            cfg.(fn{i}) = defaults.(fn{i});
        end
    end
end

function W = aggregatedWeight(candidate, cfg)
    gray = rgb2gray(candidate);
    lapKernel = fspecial('laplacian', cfg.laplacianAlpha);
    WL = abs(imfilter(gray, lapKernel, 'replicate', 'same'));
    WSat = std(candidate, 0, 3);
    WS = abs(gray - imgaussfilt(gray, cfg.saliencySigma));
    W = WL + WSat + WS;
end

function sizes = computeLevelSizes(H, W, numLevelsRequested)
    minDim = min(H, W);
    if isempty(numLevelsRequested)
        numLevelsRequested = max(1, floor(log2(minDim / 16)) + 1);
        numLevelsRequested = min(numLevelsRequested, 8);
    end
    maxLevels = max(1, floor(log2(minDim)) - 1);
    numLevels = max(1, min(numLevelsRequested, maxLevels));
    sizes = cell(numLevels, 1);
    sizes{1} = [H W];
    for l = 2:numLevels
        prev = sizes{l-1};
        sizes{l} = max(floor(prev/2), [4 4]);
    end
end

function out = pyrResize(im, targetSize)
    out = imresize(im, targetSize, 'bilinear');
end

function G = genGaussianPyramid(im, sizes)
    numLevels = numel(sizes);
    G = cell(numLevels, 1);
    G{1} = im;
    for l = 2:numLevels
        G{l} = pyrResize(G{l-1}, sizes{l});
    end
end

function L = genLaplacianPyramid(im, sizes)
    G = genGaussianPyramid(im, sizes);
    numLevels = numel(sizes);
    L = cell(numLevels, 1);
    for l = 1:numLevels-1
        expanded = pyrResize(G{l+1}, sizes{l});
        L{l} = G{l} - expanded;
    end
    L{numLevels} = G{numLevels};
end

function out = collapsePyramid(pyr, sizes)
    numLevels = numel(pyr);
    out = pyr{numLevels};
    for l = numLevels-1:-1:1
        out = pyrResize(out, sizes{l}) + pyr{l};
    end
end
