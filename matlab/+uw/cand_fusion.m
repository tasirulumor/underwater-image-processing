function [out, Wa, Wb] = cand_fusion(img, arg2, arg3)
    if nargin < 2, arg2 = struct(); end
    if nargin < 3, arg3 = struct(); end

    twoInput = isnumeric(arg2) && ndims(arg2) == 3 && size(arg2, 3) == 3;
    if twoInput
        A = im2double(img);
        B = im2double(arg2);
        cfg = arg3;
        if size(A, 3) == 4, A = A(:,:,1:3); end
        if size(B, 3) == 4, B = B(:,:,1:3); end
        [out, Wa, Wb] = ancuti_fusion(min(max(A,0),1), min(max(B,0),1), cfg);
        out = min(max(out, 0), 1);
        return;
    end

    cfg = arg2;
    if ~isstruct(cfg), cfg = struct(); end
    if ~isfield(cfg,'gamma'),        cfg.gamma        = 1.5; end
    if ~isfield(cfg,'sharpAmount'),  cfg.sharpAmount  = 1.0; end
    if ~isfield(cfg,'sharpRadius'),  cfg.sharpRadius  = 2;   end

    base = uw.wb_underwater(img);

    input1 = base .^ (1/cfg.gamma);
    input1 = min(max(input1, 0), 1);

    input2 = zeros(size(base));
    for c = 1:3
        input2(:,:,c) = imsharpen(base(:,:,c), ...
            'Radius', cfg.sharpRadius, 'Amount', cfg.sharpAmount);
    end
    input2 = min(max(input2, 0), 1);

    [out, Wa, Wb] = ancuti_fusion(input1, input2);
    out = min(max(out, 0), 1);
end
