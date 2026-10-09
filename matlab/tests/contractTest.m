classdef contractTest < matlab.unittest.TestCase
    properties (TestParameter)
        singleInputCandidate = {'wb_underwater', 'cand_clahe', 'cand_msrcr', 'cand_udcp'};
    end

    properties
        Img
        ImgB
        H = 128
        W = 128
    end

    methods (TestClassSetup)
        function makeSyntheticImages(testCase)
            rng(42, 'twister');
            [xx, yy] = meshgrid(linspace(0.15, 0.85, testCase.W), ...
                                linspace(0.15, 0.85, testCase.H));
            base = 0.5 * (xx + yy);
            img = cat(3, base, base, base);
            img = addBlob(img, 0.3, 0.3, 0.18, [0.95, 0.20, 0.15]);
            img = addBlob(img, 0.7, 0.35, 0.14, [0.10, 0.85, 0.20]);
            img = addBlob(img, 0.55, 0.75, 0.16, [0.10, 0.25, 0.90]);
            img = min(max(img + 0.02*randn(size(img)), 0), 1);
            testCase.Img = img;
            testCase.ImgB = min(max(img .* reshape([1.10, 0.98, 0.92],1,1,3), 0), 1);
        end
    end

    methods (Test)
        function singleInputCandidateContract(testCase, singleInputCandidate)
            fnName = sprintf('uw.%s', singleInputCandidate);
            testCase.assumeTrue(~isempty(which(fnName)), ...
                sprintf('skip: %s is not on the MATLAB path yet', fnName));
            fh = str2func(fnName);
            out = fh(testCase.Img);
            checkContract(testCase, out, size(testCase.Img), fnName);
        end

        function fusionContract(testCase)
            testCase.assumeTrue(~isempty(which('uw.cand_fusion')), ...
                'skip: uw.cand_fusion is not on the MATLAB path yet');
            out = uw.cand_fusion(testCase.Img, testCase.ImgB);
            checkContract(testCase, out, size(testCase.Img), 'uw.cand_fusion');
        end

        function rejectsBadRangeInput(testCase)
            testCase.assumeTrue(~isempty(which('uw.wb_underwater')), ...
                'skip: uw.wb_underwater is not on the MATLAB path yet');
            noisy = testCase.Img + 0.001;
            out = uw.wb_underwater(noisy);
            testCase.verifyTrue(all(isfinite(out(:))), ...
                'uw.wb_underwater returned non-finite values on slightly-out-of-range input');
        end
    end
end

function img = addBlob(img, cyFrac, cxFrac, rFrac, color)
    [H, W, ~] = size(img);
    cy = cyFrac * H;
    cx = cxFrac * W;
    r  = rFrac  * min(H, W);
    [xx, yy] = meshgrid(1:W, 1:H);
    d2 = (yy - cy).^2 + (xx - cx).^2;
    mask = d2 <= r^2;
    alpha = exp(-d2 / (2 * (r/2)^2)) .* mask;
    for c = 1:3
        img(:,:,c) = img(:,:,c) .* (1 - alpha) + color(c) .* alpha;
    end
end

function checkContract(tc, out, expectedSize, fnName)
    tc.verifyClass(out, 'double', sprintf('%s output must be double', fnName));
    tc.verifyEqual(size(out), expectedSize, sprintf('%s output shape mismatch', fnName));
    tc.verifyTrue(all(isfinite(out(:))), sprintf('%s output contains NaN/Inf', fnName));
    tc.verifyGreaterThanOrEqual(min(out(:)), 0 - 1e-9, sprintf('%s output has values < 0', fnName));
    tc.verifyLessThanOrEqual(max(out(:)), 1 + 1e-9, sprintf('%s output has values > 1', fnName));
end
