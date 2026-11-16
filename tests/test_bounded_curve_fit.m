function tests = test_bounded_curve_fit
tests = functiontests(localfunctions);
end

function testExponentialSynthetic(testCase)
x = (1:16)'; expected = [120 6 3];
y = expected(1)*exp(-x/expected(2))+expected(3);
[c,r,p] = ce_bounded_curve_fit('exponential',x,y,[100 5 5],[1 .001 0],[5000 50 1000],false);
verifyGreaterThan(testCase,r,0.999999);
verifyLessThan(testCase,max(abs(p-y)),0.05);
verifyEqual(testCase,c,expected,'AbsTol',0.1);
end

function testConstrainedMinimum(testCase)
x = (1:16)'; y = 300*exp(-x/90)+20;
[c,~,p] = ce_bounded_curve_fit('exponential',x,y,[200 30 10],[1 .001 0],[5000 50 1000],false);
verifyGreaterThanOrEqual(testCase,c,[1 .001 0]);
verifyLessThanOrEqual(testCase,c,[5000 50 1000]);
verifyGreaterThan(testCase,c(2),49.0);
verifyTrue(testCase,all(isfinite(p)));
end

function testAcgSynthetic(testCase)
x=(.5:.5:50)'; p=[20 1 30 2 .5 5 1.5 2];
y=max(p(3)*(exp(-(x-p(6))/p(1))-p(4)*exp(-(x-p(6))/p(2)))+p(8)*exp(-(x-p(6))/p(7))+p(5),0);
[c,r,pred]=ce_bounded_curve_fit('acg',x,y,p,[1 .1 0 0 -30 0 .1 0],[500 50 500 15 50 20 5 100],false);
verifyGreaterThan(testCase,r,.99999);verifyLessThan(testCase,max(abs(pred-y)),.01);
verifyGreaterThanOrEqual(testCase,c,[1 .1 0 0 -30 0 .1 0]);
verifyLessThanOrEqual(testCase,c,[500 50 500 15 50 20 5 100]);
end

function testInvalidInputsRejected(testCase)
verifyError(testCase,@() ce_bounded_curve_fit('exponential',[1;2],[1;NaN],[2 2 2],[1 .1 0],[5 5 5],false),'CellExplorer:InvalidFitInput');
verifyError(testCase,@() ce_bounded_curve_fit('other',[1;2],[1;2],[2 2 2],[1 .1 0],[5 5 5],false),'CellExplorer:UnknownFitModel');
end

function testToolboxComparisonWhenLicensed(testCase)
assumeTrue(testCase,ce_curvefit_available(),'Curve Fitting Toolbox seat unavailable');
x=(1:16)'; y=90*exp(-x/8)+4+0.05*sin(x);
[a,~,pa]=ce_bounded_curve_fit('exponential',x,y,[80 5 5],[1 .001 0],[5000 50 1000],true);
[b,~,pb]=ce_bounded_curve_fit('exponential',x,y,[80 5 5],[1 .001 0],[5000 50 1000],false);
verifyEqual(testCase,pb,pa,'AbsTol',.1);
verifyEqual(testCase,b(2),a(2),'AbsTol',.2);
end

function testFitAcgIntegrationWithoutToolbox(testCase)
assumeFalse(testCase,ce_curvefit_available(),'This test exercises the missing-license path');
x=(.5:.5:50)'; p=[20 1 30 2 .5 5 1.5 2];
y=max(p(3)*(exp(-(x-p(6))/p(1))-p(4)*exp(-(x-p(6))/p(2)))+p(8)*exp(-(x-p(6))/p(7))+p(5),0);
a=zeros(201,1);a(102:201)=y;
result=fit_ACG(a,false);
verifyEqual(testCase,result.curveFitBackend,'base MATLAB fminsearch');
verifyGreaterThan(testCase,result.acg_fit_rsquare,.99);
verifyTrue(testCase,isfinite(result.acg_tau_decay));
end

function testAcgRetryEscapesZeroPlateau(testCase)
x=(.5:.5:50)'; p=[14.4016 2.3085 47.2482 .5747 .8016 9.6010 1.1909 3.7424];
y=max(p(3)*(exp(-(x-p(6))/p(1))-p(4)*exp(-(x-p(6))/p(2)))+p(8)*exp(-(x-p(6))/p(7))+p(5),0);
[~,r]=ce_bounded_curve_fit('acg',x,y,[20 1 30 2 .5 5 1.5 2],[1 .1 0 0 -30 0 .1 0],[500 50 500 15 50 20 5 100],false);
verifyGreaterThan(testCase,r,.99);
end

function testToolboxAcgComparisonWhenLicensed(testCase)
assumeTrue(testCase,ce_curvefit_available(),'Curve Fitting Toolbox seat unavailable');
x=(.5:.5:50)';p=[20 1 30 2 .5 5 1.5 2];
y=max(p(3)*(exp(-(x-p(6))/p(1))-p(4)*exp(-(x-p(6))/p(2)))+p(8)*exp(-(x-p(6))/p(7))+p(5),0);
y=y+0.001*sin(x);
lo=[1 .1 0 0 -30 0 .1 0];hi=[500 50 500 15 50 20 5 100];
[~,~,toolboxPrediction]=ce_bounded_curve_fit('acg',x,y,p,lo,hi,true);
[~,~,basePrediction]=ce_bounded_curve_fit('acg',x,y,p,lo,hi,false);
verifyLessThan(testCase,norm(basePrediction-toolboxPrediction)/max(1,norm(toolboxPrediction)),.02);
end

function testWaveformAndAcgMetricsWithoutToolbox(testCase)
assumeFalse(testCase,ce_curvefit_available(),'This test exercises the missing-license path');
assumeTrue(testCase,exist('CCGHeart','file') ~= 0,'CCGHeart MEX is required');
f=generate_getWaveformsFromDat_fixture('outputRoot',tempname);
cleanup=onCleanup(@() rmdir(f.basepath,'s')); %#ok<NASGU>
s=f.session;s.spikeSorting={struct('method','synthetic')};
s.animal=struct('name','synthetic','species','Unknown','sex','Unknown','strain','Unknown');
s.extracellular.chanCoords.x=1:s.extracellular.nChannels;
s.extracellular.chanCoords.y=zeros(1,s.extracellular.nChannels);
s.extracellular.chanCoords.layout='linear';
sp=f.spikes;sp.shankID=ones(size(sp.UID));
sp.times=cellfun(@(x)x(:),sp.times,'UniformOutput',false);
sp.ts=cellfun(@(x)x(:),sp.ts,'UniformOutput',false);
sp=getWaveformsFromDat(sp,s,'showWaveforms',false,'saveMat',false,'nPull',1000000);
sp.times=cellfun(@sort,sp.times,'UniformOutput',false);
sp.ts=cellfun(@sort,sp.ts,'UniformOutput',false);
m=ProcessCellMetrics('session',s,'spikes',sp,'metrics',{'waveform_metrics','acg_metrics'}, ...
    'getWaveformsFromDat',false,'saveMat',false,'saveBackup',false, ...
    'transferFilesFromClusterpath',false,'showWaveforms',false,'showFigures',false, ...
    'sessionSummaryFigure',false,'manualAdjustMonoSyn',false);
verifyEqual(testCase,m.general.cellCount,numel(sp.times));
verifyEqual(testCase,m.general.processinginfo.params.waveformCurveFitBackend,'base MATLAB fminsearch');
verifyEqual(testCase,m.general.processinginfo.params.acgCurveFitBackend,'base MATLAB fminsearch');
end

function testLicensedWaveformFitsMatchOriginalCalls(testCase)
assumeTrue(testCase,ce_curvefit_available(),'Curve Fitting Toolbox seat unavailable');
f=generate_getWaveformsFromDat_fixture('outputRoot',tempname);
cleanup=onCleanup(@() rmdir(f.basepath,'s')); %#ok<NASGU>
rng(1);
sp=getWaveformsFromDat(f.spikes,f.session,'showWaveforms',false,'saveMat',false,'nPull',1000000);
verifyFalse(testCase,isfield(sp.processinginfo.params,'curveFitBackend'));
g=fittype('a*exp(-x/b)+c','dependent',{'y'},'independent',{'x'},'coefficients',{'a','b','c'});
for i=1:numel(sp.times)
    n=min([16 f.session.extracellular.nChannels numel(f.session.extracellular.electrodeGroups.channels{sp.shankID(i)})]);
    x=1:n;y=sp.peakVoltage_sorted{i}(x);
    original=fit(x',y',g,'StartPoint',[sp.peakVoltage(i),5,5],'Lower',[1,.001,0],'Upper',[5000,50,1000]);
    coefficients=coeffvalues(original);
    verifyEqual(testCase,sp.peakVoltage_expFitLengthConstant(i),coefficients(2),'AbsTol',1e-10);
end
end
