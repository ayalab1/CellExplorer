function results = ci_run_bounded_curve_fit(mode)
%CI_RUN_BOUNDED_CURVE_FIT Run the curve-fitting tests and require the
% tests for one backend to pass rather than be skipped by an assumption.
%   mode: 'licensed' (Curve Fitting Toolbox available) or 'fallback'
%   (toolbox not installed, base MATLAB fminsearch path).
common = {'testExponentialSynthetic','testConstrainedMinimum','testAcgSynthetic', ...
    'testInvalidInputsRejected','testAcgRetryEscapesZeroPlateau'};
switch mode
    case 'licensed'
        required = [common, {'testToolboxComparisonWhenLicensed', ...
            'testToolboxAcgComparisonWhenLicensed','testLicensedWaveformFitsMatchOriginalCalls'}];
        expectedBackend = true;
    case 'fallback'
        required = [common, {'testFitAcgIntegrationWithoutToolbox', ...
            'testWaveformAndAcgMetricsWithoutToolbox'}];
        expectedBackend = false;
    otherwise
        error('CellExplorer:UnknownCiMode','Unknown mode: %s',mode);
end
if ce_curvefit_available() ~= expectedBackend
    error('CellExplorer:UnexpectedCurveFitBackend', ...
        'ce_curvefit_available() returned %d in %s mode.',~expectedBackend,mode);
end
results = runtests('tests/test_bounded_curve_fit.m');
disp(table(results));
if any([results.Failed])
    error('CellExplorer:CurveFitTestsFailed','Curve-fitting tests failed.');
end
names = {results.Name};
for i = 1:numel(required)
    match = endsWith(names,['/',required{i}]);
    if ~any(match) || ~results(match).Passed
        error('CellExplorer:RequiredTestNotPassed','%s did not pass in %s mode.',required{i},mode);
    end
end
fprintf('All %d required %s curve-fitting tests passed.\n',numel(required),mode);
end
