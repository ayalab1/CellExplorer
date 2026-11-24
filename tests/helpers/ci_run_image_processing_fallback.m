function results = ci_run_image_processing_fallback(mode)
% Run the fallback tests, and require the native parity tests in licensed mode.
suite = testsuite('tests/test_image_processing_fallback.m');
parityTests = endsWith({suite.Name}, 'ToolboxParity');
assert(any(parityTests) && any(~parityTests), 'Expected both fallback and parity tests.');
switch mode
    case 'fallback'
        assert(isempty(ver('images')), 'This CI job requires MATLAB without Image Processing Toolbox.');
        suite = suite(~parityTests);
    case 'licensed'
        assert(ce_image_toolbox_available('medfilt2'), ...
            'Image Processing Toolbox must be installed and licensed for parity tests.');
    otherwise
        error('CellExplorer:UnknownCiMode', 'Unknown image-processing test mode: %s.', mode);
end
results = run(suite);
disp(table(results));
assert(all([results.Passed]), 'An image-processing test failed or did not run.');
end
