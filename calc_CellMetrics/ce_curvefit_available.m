function available = ce_curvefit_available()
%CE_CURVEFIT_AVAILABLE True when Curve Fitting Toolbox can be checked out.
% An installed toolbox can still be unavailable when all license seats are used.
available = false;
if exist('fit','file') ~= 2 || exist('fittype','file') ~= 2
    return
end
try
    available = license('test','Curve_Fitting_Toolbox') && ...
        license('checkout','Curve_Fitting_Toolbox');
catch
    available = false;
end
end
