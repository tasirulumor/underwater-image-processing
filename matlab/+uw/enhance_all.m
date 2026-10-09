function cands = enhance_all(img, opts)
    if nargin < 2, opts = struct(); end
    if ~isfield(opts,'exclude'), opts.exclude = {}; end
    if ~isfield(opts,'verbose'), opts.verbose = true; end

    img = im2double(img);
    if size(img,3) == 4, img = img(:,:,1:3); end
    img = min(max(img, 0), 1);

    registry = {
        'input',  @() img
        'wb',     @() uw.wb_underwater(img)
        'clahe',  @() uw.cand_clahe(img)
        'msrcr',  @() uw.cand_msrcr(img)
        'udcp',   @() uw.cand_udcp(img)
        'fusion', @() uw.cand_fusion(img)
    };
    keep = setdiff(registry(:,1), opts.exclude, 'stable');

    cands = struct('name', {}, 'image', {});
    for k = 1:numel(keep)
        name = keep{k};
        fn = registry{strcmp(registry(:,1), name), 2};
        if opts.verbose, fprintf('      running %s ...\n', name); end
        try
            out = im2double(fn());
            if size(out,3) == 4, out = out(:,:,1:3); end
            cands(end+1).name = name;
            cands(end).image = min(max(out, 0), 1);
        catch ME
            warning('uw:enhance_all:cand_failed', 'Candidate "%s" failed (%s); skipping.', name, ME.message);
        end
    end
end
