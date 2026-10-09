classdef fusionPartitionTest < matlab.unittest.TestCase
    properties
        A
        B
    end

    methods (TestClassSetup)
        function makeCandidates(testCase)
            rng(1, 'twister');
            H = 96; W = 96;
            [xx, yy] = meshgrid(linspace(0.15, 0.85, W), linspace(0.15, 0.85, H));
            base = 0.5 * (xx + yy);
            A = cat(3, base, base, base);
            A = min(max(A + 0.03*randn(size(A)), 0), 1);
            B = min(max(A .* reshape([1.08, 0.98, 0.92], 1, 1, 3), 0), 1);
            testCase.A = A;
            testCase.B = B;
        end
    end

    methods (Test)
        function fusionWrapperReturnsValidImage(testCase)
            testCase.assumeTrue(~isempty(which('uw.cand_fusion')), ...
                'skip: uw.cand_fusion is not on the MATLAB path yet');
            out = uw.cand_fusion(testCase.A, testCase.B);
            testCase.verifyClass(out, 'double');
            testCase.verifyEqual(size(out), size(testCase.A));
            testCase.verifyTrue(all(isfinite(out(:))), 'uw.cand_fusion returned non-finite values');
            testCase.verifyGreaterThanOrEqual(min(out(:)), 0 - 1e-9);
            testCase.verifyLessThanOrEqual(max(out(:)), 1 + 1e-9);
        end

        function weightMapsFormPartitionOfUnity(testCase)
            testCase.assumeTrue(exist('ancuti_fusion', 'file') ~= 0, ...
                'skip: methods/ancuti_fusion is not on the MATLAB path');
            [~, Wa, Wb] = ancuti_fusion(testCase.A, testCase.B);
            testCase.verifyEqual(size(Wa), size(Wb), 'Wa and Wb must have identical shape');
            testCase.verifyEqual(size(Wa,1), size(testCase.A,1));
            testCase.verifyEqual(size(Wa,2), size(testCase.A,2));
            testCase.verifyTrue(all(isfinite(Wa(:))));
            testCase.verifyTrue(all(isfinite(Wb(:))));
            sum_map = Wa + Wb;
            maxDev = max(abs(sum_map(:) - 1));
            testCase.verifyLessThan(maxDev, 1e-10, ...
                sprintf('Wa+Wb deviates from 1 by %g (max)', maxDev));
            testCase.verifyGreaterThan(min(Wa(:)), 0);
            testCase.verifyGreaterThan(min(Wb(:)), 0);
            testCase.verifyLessThan(max(Wa(:)), 1);
            testCase.verifyLessThan(max(Wb(:)), 1);
        end
    end
end
