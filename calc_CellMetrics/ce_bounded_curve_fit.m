function [coefficients, rsquare, prediction] = ce_bounded_curve_fit(model,x,y,start,lower,upper,useToolbox)
%CE_BOUNDED_CURVE_FIT Fit a bounded CellExplorer model by least squares.
% With no Curve Fitting Toolbox license, use MATLAB's base fminsearch with
% a bounded transformation. The optimizer can produce different parameter
% estimates from fit, especially for poorly identified or noisy data.
x = double(x(:)); y = double(y(:));
start = double(start(:)'); lower = double(lower(:)'); upper = double(upper(:)');
if numel(x) ~= numel(y) || isempty(x) || any(~isfinite(x)) || any(~isfinite(y)) || ...
        numel(start) ~= numel(lower) || numel(start) ~= numel(upper) || ...
        any(~isfinite(start)) || any(~isfinite(lower)) || any(~isfinite(upper)) || ...
        any(lower >= upper) || any(start < lower) || any(start > upper)
    error('CellExplorer:InvalidFitInput','Fit inputs must be finite and within valid bounds.');
end
switch model
    case 'exponential'
        expression = 'a*exp(-x/b)+c';
        coefficientNames = {'a','b','c'};
        equation = @(p,x) p(1).*exp(-x./p(2))+p(3);
    case 'acg'
        expression = 'max(c*(exp(-(x-f)/a)-d*exp(-(x-f)/b))+h*exp(-(x-f)/g)+e,0)';
        coefficientNames = {'a','b','c','d','e','f','g','h'};
        equation = @(p,x) max(p(3).*(exp(-(x-p(6))./p(1))-p(4).*exp(-(x-p(6))./p(2)))+p(8).*exp(-(x-p(6))./p(7))+p(5),0);
    otherwise
        error('CellExplorer:UnknownFitModel','Unknown fitting model: %s',model);
end
if numel(start) ~= numel(coefficientNames)
    error('CellExplorer:InvalidFitInput','Wrong number of model coefficients.');
end
if useToolbox
    persistent exponentialType acgType
    if strcmp(model,'exponential')
        if isempty(exponentialType), exponentialType = fittype(expression,'dependent',{'y'},'independent',{'x'},'coefficients',coefficientNames); end
        ft = exponentialType;
    else
        if isempty(acgType), acgType = fittype(expression,'dependent',{'y'},'independent',{'x'},'coefficients',coefficientNames); end
        ft = acgType;
    end
    [f,gof] = fit(x,y,ft,'StartPoint',start,'Lower',lower,'Upper',upper);
    coefficients = coeffvalues(f);
    rsquare = gof.rsquare;
    prediction = f(x);
else
    span = upper-lower;
    map = @(z) lower + span .* (sin(z)+1)/2;
    % Stay slightly inside each bound so fminsearch can move away from it.
    scaled = max(-1+1e-8,min(1-1e-8,2*(start-lower)./span-1));
    z0 = asin(scaled);
    scale = max(1,max(abs(y)));
    objective = @(z) sum(((equation(map(z),x)-y)./scale).^2);
    options = optimset('Display','off','MaxFunEvals',20000,'MaxIter',20000,'TolX',1e-8,'TolFun',1e-10);
    [z,bestScore,exitflag] = fminsearch(objective,z0,options);
    % ACG fits can get stuck on the model's zero plateau. Retry poor fits
    % from two deterministic nearby starts, keeping the best objective.
    totalScore = sum(((y-mean(y))./scale).^2);
    if strcmp(model,'acg') && totalScore > 0 && bestScore > 0.02*totalScore
        for factor = [0.5, 4]
            alternative = start;
            alternative([1,2,3,4,7,8]) = alternative([1,2,3,4,7,8])*factor;
            alternative = max(lower,min(upper,alternative));
            scaledAlt = max(-1+1e-8,min(1-1e-8,2*(alternative-lower)./span-1));
            [zAlt,scoreAlt,exitAlt] = fminsearch(objective,asin(scaledAlt),options);
            if scoreAlt < bestScore
                z = zAlt; bestScore = scoreAlt; exitflag = exitAlt;
            end
        end
    end
    if exitflag <= 0
        warning('CellExplorer:FitDidNotConverge','Base MATLAB fit did not converge for %s.',model);
    end
    coefficients = map(z);
    prediction = equation(coefficients,x);
    ssRes = sum((y-prediction).^2);
    ssTotal = sum((y-mean(y)).^2);
    if ssTotal == 0
        rsquare = NaN;
    else
        rsquare = 1-ssRes/ssTotal;
    end
end
end
