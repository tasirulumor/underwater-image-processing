function pick = run_one(input_path, opts)
    if nargin < 2, opts = struct(); end
    here = fileparts(fileparts(mfilename('fullpath')));
    if ~isfield(opts,'out_dir'),      opts.out_dir      = fullfile(here,'..','results'); end
    if ~isfield(opts,'max_dim'),      opts.max_dim      = 1024; end
    if ~isfield(opts,'exclude'),      opts.exclude      = {};   end
    if ~isfield(opts,'open_preview'), opts.open_preview = true; end
    if ~isfield(opts,'verbose'),      opts.verbose      = true; end
    if ~isfield(opts,'preset'),       opts.preset       = '';   end

    addpath(here); addpath(fullfile(here,'methods'));
    if ~isfolder(opts.out_dir), mkdir(opts.out_dir); end

    img = im2double(imread(input_path));
    if size(img,3) == 4, img = img(:,:,1:3); end
    [~, stem] = fileparts(input_path);
    if isfinite(opts.max_dim) && max(size(img,1),size(img,2)) > opts.max_dim
        img = imresize(img, opts.max_dim/max(size(img,1),size(img,2)), 'bilinear');
    end
    odir = fullfile(opts.out_dir, stem);
    cdir = fullfile(odir, 'candidates');
    if ~isfolder(cdir), mkdir(cdir); end

    fprintf('[run_one] %s | generating candidates\n', stem);
    cands = uw.enhance_all(img, struct('exclude',{opts.exclude},'verbose',opts.verbose));
    for c = 1:numel(cands)
        imwrite(cands(c).image, fullfile(cdir, [cands(c).name '.png']));
    end

    preview_path = fullfile(odir, 'preview.png');
    try, imwrite(numberedPreview_(cands), preview_path); catch, end
    if opts.open_preview, try, winopen(preview_path); catch, end; end

    n = numel(cands);
    fprintf('\nCandidates:\n');
    for i = 1:n
        fprintf('  [%d] %s\n', i, cands(i).name);
    end

    if isempty(opts.preset)
        fprintf('\nEnter candidates with weights, e.g. 4:60,5:30,6:10\n');
        fprintf('(a single number = that candidate; "quit" to abort)\n');
        raw = strtrim(input('> your choice: ', 's'));
    else
        raw = strtrim(opts.preset);
    end

    if isempty(raw) || strcmpi(raw,'quit')
        fprintf('[run_one] %s | aborted\n', stem);
        pick = struct('name','', 'image',[], ...
            'paths',struct('candidates',cdir,'preview',preview_path));
        return;
    end

    [idx, wt] = parseChoice_(raw, n);
    if isempty(idx)
        error('uw:run_one:badChoice', 'No valid candidate numbers in "%s".', raw);
    end

    if numel(idx) == 1
        best = cands(idx).image;
        name = cands(idx).name;
    else
        wt = wt / sum(wt);
        imgs = cell(numel(idx),1);
        for k = 1:numel(idx), imgs{k} = cands(idx(k)).image; end
        best = min(max(uw.blend_score_weighted(imgs, wt, struct('weight_bias',1)), 0), 1);
        parts = arrayfun(@(k) sprintf('%s(%d%%)', cands(idx(k)).name, round(100*wt(k))), ...
            1:numel(idx), 'UniformOutput', false);
        name = ['blend:' strjoin(parts, '+')];
    end

    best_path = fullfile(odir, 'best.png');
    mont_path = fullfile(odir, 'montage.png');
    imwrite(best, best_path);
    try, imwrite(uw.make_montage(cands, struct('name',name,'image',best)), mont_path); catch, end

    fprintf('[run_one] %s | CHOSEN -> %s\n', stem, name);
    pick = struct('name',name, 'image',best, ...
        'paths',struct('best',best_path,'montage',mont_path,'candidates',cdir,'preview',preview_path));
end

function [idx, wt] = parseChoice_(raw, n)
    tok = regexp(raw, '\(\s*(\d+)\s*,\s*(\d+)\s*\)', 'tokens');
    if isempty(tok)
        tok = regexp(raw, '(\d+)\s*:\s*(\d+)', 'tokens');
    end
    if ~isempty(tok)
        idx = cellfun(@(t) str2double(t{1}), tok);
        wt  = cellfun(@(t) str2double(t{2}), tok);
    else
        nums = sscanf(regexprep(raw, '[^0-9 ]', ' '), '%d');
        idx = nums(:).';
        wt  = ones(1, numel(idx));
    end
    valid = idx >= 1 & idx <= n & isfinite(idx);
    idx = idx(valid); wt = wt(valid);
    [idx, ia] = unique(idx, 'stable'); wt = wt(ia);
    wt(wt <= 0) = 1;
end

function mont = numberedPreview_(cands)
    n = numel(cands); tileW = 480; barH = 28;
    [h0, w0, ~] = size(cands(1).image);
    tileH = max(64, round(h0 * tileW / max(w0,1)));
    tiles = cell(n,1);
    for i = 1:n
        t = min(max(im2double(cands(i).image),0),1);
        if size(t,3) == 4, t = t(:,:,1:3); end
        t = imresize(t, [tileH, tileW], 'bilinear');
        m = [t; zeros(barH, tileW, 3)];
        try
            m = insertText(m, [8, tileH+4], sprintf('%d) %s', i, cands(i).name), ...
                'FontSize',14,'BoxOpacity',0,'TextColor','white');
        catch
        end
        if size(m,1) ~= tileH+barH, m = imresize(m, [tileH+barH, tileW]); end
        tiles{i} = m;
    end
    cols = 3; rows = ceil(n/cols);
    while numel(tiles) < rows*cols, tiles{end+1} = ones(tileH+barH, tileW, 3); end
    strips = cell(rows,1);
    for r = 1:rows, strips{r} = cat(2, tiles{(r-1)*cols+1:(r-1)*cols+cols}); end
    mont = min(max(cat(1, strips{:}), 0), 1);
end
