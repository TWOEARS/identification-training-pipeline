function trainAndTestSegmented()

startTwoEars('tt_segmented.config.xml');
segmModelFileName = '70c4feac861e382413b4c4bfbf895695.mat';
mkdir( fullfile( db.tmp, 'learned_models', 'SegmentationKS' ) );
copyfile( ['./' segmModelFileName], ...
          fullfile( db.tmp, 'learned_models', 'SegmentationKS', segmModelFileName ), ...
          'f' );

%% training
if ~exist( fullfile( 'test_segmented', 'segmModel.model.mat' ), 'file' )
% pipeline creation
pipe = TwoEarsIdTrainPipe( 'cacheSystemDir', [getMFilePath() '/../../idPipeCache'] );
pipe.ksWrapper = DataProcs.SegmentKsWrapper( ...
    'SegmentationTrainerParameters5.yaml', ...
    'useDnnLocKs', false, ...
    'useNsrcsKs', false, ...
    'segSrcAssignmentMethod', 'minDistance', ...
    'varAzmSigma', 0, ...
    'nsrcsBias', 0, ...
    'nsrcsRndPlusMinusBias', 0, ...
    'softMaskExponent', 10 );
pipe.blockCreator = BlockCreators.MeanStandardBlockCreator( 0.5, 1./3 );
pipe.featureCreator = FeatureCreators.FeatureSet5bBlockmean();
pipe.labelCreator = LabelCreators.MultiEventTypeLabeler( 'types', {{'speech'}}, 'negOut', 'rest', ...
                                                         'labelBlockSize_s', 0.5 );
pipe.modelCreator = ModelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @PerformanceMeasures.ImportanceWeightedSquareBalancedAccuracy, ...
    'maxDataSize', 5000, ...
    'dataSelector', DataSelectors.BAC_NPP_NS_Selector( false ), ...
    'importanceWeighter', ImportanceWeighters.BAC_NS_NPP_Weighter(), ...
    'cvFolds', 'preFolded', ...  % most reasonable if supplying prefolded dataset definitions
    'alpha', 0.99 );  % prevents numeric instabilities (compared to 1)
pipe.modelCreator.verbose( 'on' );
ModelTrainers.CVtrainer.useParallelComputing( true );

% data setup
pipe.setTrainset( {'DCASE13_mini_TrainSet_f1.flist',...
                   'DCASE13_mini_TrainSet_f2.flist',...
                   'DCASE13_mini_TrainSet_f3.flist',...
                   'DCASE13_mini_TrainSet_f4.flist'} );
pipe.setupData();

% scenes setup
sc(1) = SceneConfig.SceneConfiguration();
sc(1).addSource( SceneConfig.PointSource( ...
                     'azimuth',SceneConfig.ValGen('manual',-45), ...
                     'data', SceneConfig.FileListValGen( 'pipeInput' )  )  );
sc(1).addSource( SceneConfig.PointSource( ...
                     'azimuth',SceneConfig.ValGen('manual',+45), ...
                     'data', SceneConfig.MultiFileListValGen( pipe.srcDataSpec ) ),...
                 'snr', SceneConfig.ValGen( 'manual', 0 ),...
                 'loop', 'randomSeq' );
sc(1).setLengthRef( 'source', 1, 'min', 30 );
sc(1).setSceneNormalization( true, 1 )
sc(2) = SceneConfig.SceneConfiguration();
sc(2).addSource( SceneConfig.PointSource( ...
                     'azimuth',SceneConfig.ValGen('manual',-60), ...
                     'data', SceneConfig.FileListValGen( 'pipeInput' )  )  );
sc(2).addSource( SceneConfig.PointSource( ...
                     'azimuth',SceneConfig.ValGen('manual',-30), ...
                     'data', SceneConfig.MultiFileListValGen( pipe.srcDataSpec ) ),...
                 'snr', SceneConfig.ValGen( 'manual', 0 ),...
                 'loop', 'randomSeq' );
sc(2).addSource( SceneConfig.PointSource( ...
                     'azimuth',SceneConfig.ValGen('manual',0), ...
                     'data', SceneConfig.MultiFileListValGen( pipe.srcDataSpec ) ),...
                 'snr', SceneConfig.ValGen( 'manual', 0 ),...
                 'loop', 'randomSeq' );
sc(2).setLengthRef( 'source', 1, 'min', 30 );
sc(2).setSceneNormalization( true, 1 )
pipe.init( sc, 'fs', 16000, 'loadBlockAnnotations', true, ...
           'dataSelector', DataSelectors.BAC_NPP_NS_Selector( false ), 'selectPrioClass', 1, ...
           'classesOnMultipleSourcesFilter', ...
               {{'clearthroat'},{'keys'},{'knock'},{'speech'},{'switch'}} );

% pipeline run
modelPath = pipe.pipeline.run( 'modelName', 'segmModel', 'modelPath', 'test_segmented' );
fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

else
disp( 'Already trained; only testing' );
end

%% testing
dcaseClasses = {{'alert'},{'clearthroat'},{'cough'},{'doorslam'},{'drawer'},{'keyboard'},...
                {'keys'},{'knock'},{'laughter'},{'mouse'},{'pageturn'},...
                {'pendrop'},{'phone'},{'speech'},{'switch'},{'void'}};
scp(1).azms = [-45,0];

% pipeline creation
pipe = TwoEarsIdTrainPipe( 'cacheSystemDir', [getMFilePath() '/../../idPipeCache'] );
pipe.ksWrapper = DataProcs.SegmentKsWrapper( ...
    'SegmentationTrainerParameters5.yaml', ...
    'useDnnLocKs', false, ...
    'useNsrcsKs', false, ...
    'segSrcAssignmentMethod', 'minDistance', ...
    'varAzmSigma', 0, ...
    'nsrcsBias', 0, ...
    'nsrcsRndPlusMinusBias', 0, ...
    'softMaskExponent', 10 );
pipe.blockCreator = BlockCreators.MeanStandardBlockCreator( 0.5, 1./3 );
pipe.featureCreator = FeatureCreators.FeatureSet5bBlockmean();
pipe.labelCreator = LabelCreators.MultiEventTypeLabeler( 'types', {{'speech'}}, 'negOut', 'rest', ...
       'labelBlockSize_s', 0.5, 'segIdTargetSrcFilter', [1,1] ); % target sounds only on source 1 );
pipe.modelCreator = ModelTrainers.LoadModelNoopTrainer( ...
    [pwd filesep 'test_segmented/segmModel.model.mat'], ...
    'performanceMeasure', @PerformanceMeasures.BAC_BAextended, ...
    'dataSelector', DataSelectors.BAC_NPP_NS_Selector( false ), ...
    'importanceWeighter', ImportanceWeighters.IgnorantWeighter(), ...
    'maxTestDataSize', 1e5 ); % GLMNET can't cope with more than 2GB
pipe.modelCreator.verbose( 'on' );
PerformanceMeasures.BAC_BAextended.classList( dcaseClasses );

%data setup
pipe.setTestset( {'DCASE13_mini_TestSet.flist'} );
pipe.setupData();

% scene setup
sc = SceneConfig.SceneConfiguration();
sc.addSource( SceneConfig.PointSource( ...
                     'azimuth',SceneConfig.ValGen('manual',scp(1).azms(1)), ...
                     'data', SceneConfig.FileListValGen( 'pipeInput' )  )  );
sc.addSource( SceneConfig.PointSource( ...
                     'azimuth',SceneConfig.ValGen('manual',scp(1).azms(2)), ...
                     'data', SceneConfig.MultiFileListValGen( pipe.srcDataSpec ) ),...
                 'snr', SceneConfig.ValGen( 'manual', 0 ),...
                 'loop', 'randomSeq' );
sc.setLengthRef( 'source', 1, 'min', 30 );
sc.setSceneNormalization( true, 1 )
pipe.init( sc, 'fs', 16000, 'loadBlockAnnotations', true, ...
           'dataSelector', DataSelectors.BAC_NPP_NS_Selector( false ),...
           'classesOnMultipleSourcesFilter', ...
               {{'clearthroat'},{'keys'},{'knock'},{'speech'},{'switch'}} );

[modelPath,model,testPerf] = pipe.pipeline.run( 'modelName', 'segmModel', 'modelPath', 'test_segmented' );
fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

%% short analysis
cmpCvAndTestPerf( modelPath, true );
plotCVperfNCoefLambda( model );

fDescription = pipe.featureCreator.description;
[~,fImpacts] = model.getBestLambdaCVresults();
plotDetailFsProfile( fDescription, fImpacts, '', false );


[sens_b,spec_b] = getPerformanceDecorrMaximumSubset( testPerf.resc_b, ...
                                                     [testPerf.resc_b.id.posPresent] );
sens_b = sens_b(2);
spec_b_npp = spec_b(1);
spec_b_pp = spec_b(2);
fprintf( 'Sensitivity/stream-wise: %.2f\n', sens_b );
fprintf( 'Specificity/stream-wise/positive present: %.2f\n', spec_b_pp );
fprintf( 'Specificity/stream-wise/no positive present: %.2f\n', spec_b_npp );

[sens_t,spec_t] = getPerformanceDecorrMaximumSubset( testPerf.resc_t );
bac_t = 0.5*sens_t+0.5*spec_t;
fprintf( 'Sensitivity/time-wise: %.2f\n', sens_t );
fprintf( 'Specificity/time-wise: %.2f\n', spec_t );
fprintf( 'BAC/time-wise: %.2f\n', bac_t );

rs_t_pp = testPerf.resc_t.filter( testPerf.resc_t.id.posPresent, @(x)(x==1) );
rs_t_ppd = rs_t_pp.filter( rs_t_pp.id.nYp, @(x)(x==1) );
azmErr_ppd = getAttributeDecorrMaximumSubset( rs_t_ppd, rs_t_ppd.id.azmErr, ...
                                              [rs_t_ppd.id.scpId], ...
                                              {[rs_t_ppd.id.classIdx],[],false;},...
                                              {},...
                                              [rs_t_ppd.id.fileClassId,rs_t_ppd.id.fileId] );
azmErr_ppd = (azmErr_ppd-1)*5;
fprintf( 'AzmErr/positive present and detected: %.2f\n', azmErr_ppd );

nyp_ppd = getAttributeDecorrMaximumSubset( rs_t_ppd, rs_t_ppd.id.nYp );
nyp_ppd = nyp_ppd - 1;
fprintf( 'NEP/positive present and detected: %.2f\n', nyp_ppd - 1 );

rs_t_npp = testPerf.resc_t.filter( testPerf.resc_t.id.posPresent, @(x)(x==2) );
nyp_npp = getAttributeDecorrMaximumSubset( rs_t_npp, rs_t_npp.id.nYp );
nyp_npp = nyp_npp - 1;
fprintf( 'NP/no positive present: %.2f\n', nyp_npp );

% conditioned on: positive present and detected
rs_b_pp = testPerf.resc_b.filter( testPerf.resc_b.id.posPresent, @(x)(x==1) );
rs_b_ppd = rs_b_pp.filter( rs_b_pp.id.nYp, @(x)(x==1) );
[placementLlh_scp_azms_ppd, ~, ~, bapr_scp_ppd] = getAzmPlacement( rs_b_ppd, rs_t_ppd, 'estAzm', 0 );
[llhTPplacem_stats_avgNsp,azmsInterp] = computeInterpPlacementLlh( placementLlh_scp_azms_ppd, ...
                                                                   scp, 5, true, [], [], [], true );

fprintf( 'BAPR: %.2f\n', bapr_scp_ppd );

figure;
hold on;
patch( [azmsInterp, flip( azmsInterp )], [llhTPplacem_stats_avgNsp(2,:), flip( llhTPplacem_stats_avgNsp(3,:))], 1, 'facealpha', 0.1, 'edgecolor', 'none', 'facecolor', [0,0,0.8] );
plot( azmsInterp, llhTPplacem_stats_avgNsp(6,:), 'DisplayName', 'median', 'LineWidth', 2, 'color', [0,0,0.8] );
ylabel( 'Placement likelihood' );
ylim( [0 1] );
xlim( [0 180] );
xlabel( 'Distance to correct azimuth (�)' );
set( gca, 'XTick', [0,20,45,90,135,180] );
title( 'Interpolated Placement Likelihood' );



end



