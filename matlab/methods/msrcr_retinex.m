function out = msrcr_retinex(img, cfg)
    if nargin < 2 || isempty(cfg)
        cfg = struct();
    end
    cfg = fillDefaults(cfg);

    if ~isa(img, 'double')
        error('msrcr_retinex:badInput', 'Input must be a double array in [0,1]. Use im2double first.');
    end
    img = min(max(img, 0), 1);
    epsVal = cfg.epsVal;

    imgSafe = img + epsVal;
    logI = log(imgSafe);

    numScales = numel(cfg.sigmas);
    R = zeros(size(img));
    for n = 1:numScales
        Gn = imgaussfilt(imgSafe, cfg.sigmas(n));
        R = R + (cfg.weights(n)) * (logI - log(Gn + epsVal));
    end

    channelSum = sum(imgSafe, 3);
    CRF = cfg.beta * (log(cfg.alpha * imgSafe) - log(channelSum));
    msrcr = CRF .* R;

    out = rescaleToDisplayGlobal(msrcr, cfg.clipPct);
    out = min(max(out, 0), 1);
end

function cfg = fillDefaults(cfg)
    defaults.sigmas  = [15 80 250];
    defaults.weights = [1 1 1]/3;
    defaults.alpha   = 125;
    defaults.beta    = 46;
    defaults.epsVal  = 1e-6;
    defaults.clipPct = 1;
    fn = fieldnames(defaults);
    for i = 1:numel(fn)
        if ~isfield(cfg, fn{i}) || isempty(cfg.(fn{i}))
            cfg.(fn{i}) = defaults.(fn{i});
        end
    end
end

function out = rescaleToDisplayGlobal(x, clipPct)
    lo = simplePercentile(x, clipPct);
    hi = simplePercentile(x, 100 - clipPct);
    if hi - lo < 1e-9
        out = 0.5 * ones(size(x));
    else
        out = (x - lo) / (hi - lo);
    end
end

function p = simplePercentile(v, pct)
    v = sort(v(:));
    n = numel(v);
    if n == 0
        p = 0;
        return;
    end
    idx = max(1, min(n, round(pct/100 * n)));
    p = v(idx);
end
