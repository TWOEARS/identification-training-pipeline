function trainAndTestBlackboardEmbedded( modelpath_, classIdx, execBaseline )

addPathsIfNotIncluded( cleanPathFromRelativeRefs( [pwd '/..'] ) ); 
startAMLTTP();

classes = {{'alarm'},{'baby'},{'femaleSpeech'},{'fire'},{'crash'},{'dog'},...
           {'engine'},{'footsteps'},{'knock'},{'phone'},{'piano'},...
           {'maleSpeech'},{'femaleScream','maleScream'}};
for ii = 1 : numel( classes )
    labelCreators{ii,1} = 'LabelCreators.MultiEventTypeLabeler'; %#ok<AGROW>
    labelCreators{ii,2} = {'types', classes(ii), ...
                           'negOut', 'rest', ...
                           'srcTypeFilterOut', [2,1;3,1;4,1]}; %#ok<AGROW> % target sounds only on source 1
end
datasets = {'learned_models/IdentityKS/trainTestSets/NIGENS160807_8-foldSplit_fold1_mini.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_8-foldSplit_fold2_mini.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_8-foldSplit_fold3_mini.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_8-foldSplit_fold4_mini.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_8-foldSplit_fold5_mini.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_8-foldSplit_fold6_mini.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_8-foldSplit_fold7_mini.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_8-foldSplit_fold8_mini.flist'};
            
dd = 1:3;
if nargin < 2 || isempty( classIdx )
    classIdx = 2;
end
if nargin < 3 || isempty( execBaseline )
    execBaseline = false;
end

if ~execBaseline
    modelname = 'bbsEmbModel';
    modelpath = 'test_bbsEmbedded';
else
    modelname = 'bbsEmbModel_baselineCmp';
    modelpath = 'test_bbsEmbedded_baselineCmp';
end

%% define blackboard
    function bbs = buildBBS()
        % setup blackboard system to be embedded into pipe
        bbs = BlackboardSystem(0);
        idModels = setDefaultIdModels();
        afeCon = BlackboardEmbedding.AuditoryFrontEndConnection();
        bbs.setRobotConnect(afeCon);
        bbs.setDataConnect('BlackboardEmbedding.AuditoryFrontEndBridgeKS', 0.2);
        ppRemoveDc = false;
        for ii = 1 : numel( idModels )
            idKss{ii} = bbs.createKS('IdentityKS', {idModels(ii).name, idModels(ii).dir, ppRemoveDc});
            idKss{ii}.setInvocationFrequency(10);
        end
        bbs.blackboardMonitor.bind({bbs.scheduler}, {bbs.dataConnect}, 'replaceOld', 'AgendaEmpty' );
        bbs.blackboardMonitor.bind({bbs.dataConnect}, idKss, 'replaceOld' );
    end

%% train

if nargin < 1 || isempty( modelpath_ )

pipe = TwoEarsIdTrainPipe();
pipe.blockCreator = BlockCreators.MeanStandardBlockCreator( 1.0, 1./3 );
if ~execBaseline
    % embed blackboard system into pipe    
    pipe.featureCreator = FeatureCreators.FullStreamIdProbStatsIntegrated( FeatureCreators.FeatureSet5cBlockmean() );
    pipe.blackboardSystem = DataProcs.BlackboardSystemWrapper( buildBBS() , pipe.featureCreator );
else
    pipe.featureCreator = FeatureCreators.FeatureSet5cBlockmean();
end
pipe.labelCreator = feval( labelCreators{classIdx,1}, labelCreators{classIdx,2}{:} );
pipe.modelCreator = ModelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @PerformanceMeasures.ImportanceWeightedSquareBalancedAccuracy, ...
    'maxDataSize', 5000, ...
    'dataSelector', DataSelectors.BAC_Selector(), ...
    'importanceWeighter', ImportanceWeighters.BAC_Weighter(), ...
    'cvFolds', 4, ...
    'alpha', 0.99 );
pipe.modelCreator.verbose( 'on' );

pipe.setTrainset( datasets(dd) );
pipe.setupData();

srcDataSpec = cell( 1, numel( pipe.pipeline.trainSet.folds ) );
wfasgns = cell( 1, numel( pipe.pipeline.trainSet.folds ) );
for kk = 1 : numel( pipe.pipeline.trainSet.folds )
    trainFold_kk = pipe.pipeline.trainSet.folds{kk};
    srcDataSpec{kk} = trainFold_kk(:,'fileName');
    wfasgns{kk} = repmat( {dd(kk)}, size( srcDataSpec{kk} ) );
end

sc(1) = SceneConfig.SceneConfiguration();
sc(1).addSource( SceneConfig.PointSource( ...
    'azimuth',SceneConfig.ValGen('manual',45), ...
    'data', SceneConfig.FileListValGen( 'pipeInput' ) )...
    );
sc(1).addSource( SceneConfig.PointSource( ...
        'azimuth',SceneConfig.ValGen('manual',-45), ...
        'data', SceneConfig.MultiFileListValGen( srcDataSpec ),...
        'offset', SceneConfig.ValGen( 'manual', 0.25 ) ), ...
    'snr', SceneConfig.ValGen( 'manual', 0 ),...
    'loop', 'randomSeq' ...
    );
sc(1).setLengthRef( 'source', 1, 'min', 30 );
sc(1).setSceneNormalization( true, 1 );
sc(2) = SceneConfig.SceneConfiguration();
sc(2).addSource( SceneConfig.PointSource( ...
    'azimuth',SceneConfig.ValGen('manual',90), ...
    'data', SceneConfig.FileListValGen( 'pipeInput' ) )...
    );
sc(2).addSource( SceneConfig.PointSource( ...
        'azimuth',SceneConfig.ValGen('manual',0), ...
        'data', SceneConfig.MultiFileListValGen( srcDataSpec ),...
        'offset', SceneConfig.ValGen( 'manual', 0.25 ) ), ...
    'snr', SceneConfig.ValGen( 'manual', -10 ),...
    'loop', 'randomSeq' ...
    );
sc(2).setLengthRef( 'source', 1, 'min', 30 );
sc(2).setSceneNormalization( true, 1 );

pipe.init( sc, 'wavFoldAssignments', [cat( 1, srcDataSpec{:} ),cat( 1, wfasgns{:} )], ...
           'fs', 16000, 'loadBlockAnnotations', true, ...
           'classesOnMultipleSourcesFilter', classes, ...
           'sceneCfgDataUseRatio', inf, 'sceneCfgPrioDataUseRatio', inf, ...
           'dataSelector', DataSelectors.BAC_Selector(), 'selectPrioClass', +1, ...
           'trainerFeedDataType', @single );
modelpath_ = pipe.pipeline.run( 'modelName', modelname, 'modelPath', modelpath, ...
                               'debug', true  );

fprintf( ' -- Model is saved at %s -- \n\n', modelpath_ );

end

%% test

pipe = TwoEarsIdTrainPipe();
pipe.blockCreator = BlockCreators.MeanStandardBlockCreator( 1.0, 1./3 );
if ~execBaseline
    % embed blackboard system into pipe    
    pipe.featureCreator = FeatureCreators.FullStreamIdProbStats5aBlockmean();
    pipe.blackboardSystem = DataProcs.BlackboardSystemWrapper( buildBBS() , pipe.featureCreator);
else
    pipe.featureCreator = FeatureCreators.FeatureSet5cBlockmean();
end
pipe.labelCreator = feval( labelCreators{classIdx,1}, labelCreators{classIdx,2}{:} );
pipe.modelCreator = ModelTrainers.LoadModelNoopTrainer( ...
    [pwd filesep modelpath filesep modelname '.model.mat'], ...
    'performanceMeasure', @PerformanceMeasures.BAC );
pipe.modelCreator.verbose( 'on' );

pipe.setTrainset( datasets(7:8) );
pipe.setupData();

srcDataSpec = cell( 1, numel( pipe.pipeline.testSet.folds ) );
wfasgns = cell( 1, numel( pipe.pipeline.testSet.folds ) );
for kk = 1 : numel( pipe.pipeline.testSet.folds )
    testFold_kk = pipe.pipeline.testSet.folds{kk};
    srcDataSpec{kk} = testFold_kk(:,'fileName');
    wfasgns{kk} = repmat( {dd(kk)}, size( srcDataSpec{kk} ) );
end

sc(1) = SceneConfig.SceneConfiguration();
sc(1).addSource( SceneConfig.PointSource( ...
    'azimuth',SceneConfig.ValGen('manual',45), ...
    'data', SceneConfig.FileListValGen( 'pipeInput' ) )...
    );
sc(1).addSource( SceneConfig.PointSource( ...
		'azimuth',SceneConfig.ValGen('manual',-45), ...
		'data', SceneConfig.MultiFileListValGen( srcDataSpec ),...
		'offset', SceneConfig.ValGen( 'manual', 0.25 ) ), ...
    'snr', SceneConfig.ValGen( 'manual', 0 ),...
    'loop', 'randomSeq' ...
    );
sc(1).setLengthRef( 'source', 1, 'min', 30 );
sc(1).setSceneNormalization( true, 1 );
sc(2) = SceneConfig.SceneConfiguration();
sc(2).addSource( SceneConfig.PointSource( ...
    'azimuth',SceneConfig.ValGen('manual',90), ...
    'data', SceneConfig.FileListValGen( 'pipeInput' ) )...
    );
sc(2).addSource( SceneConfig.PointSource( ...
		'azimuth',SceneConfig.ValGen('manual',0), ...
        'data', SceneConfig.MultiFileListValGen( srcDataSpec ),...
		'offset', SceneConfig.ValGen( 'manual', 0.25 ) ), ...
    'snr', SceneConfig.ValGen( 'manual', -10 ),...
    'loop', 'randomSeq' ...
    );
sc(2).setLengthRef( 'source', 1, 'min', 30 );
sc(2).setSceneNormalization( true, 1 );

pipe.init( sc, 'wavFoldAssignments', [cat( 1, srcDataSpec{:} ),cat( 1, wfasgns{:} )], ...
           'fs', 16000, 'loadBlockAnnotations', true, ...
           'classesOnMultipleSourcesFilter', classes, ...
           'sceneCfgDataUseRatio', inf, 'sceneCfgPrioDataUseRatio', inf, ...
           'dataSelector', DataSelectors.BAC_Selector(), 'selectPrioClass', +1, ...
           'trainerFeedDataType', @single );
[modelpath_,~,testPerfresults] = ...
             pipe.pipeline.run( 'modelName', modelname, 'modelPath', modelpath, ...
                                'debug', true  );

fprintf( ' -- Model is saved at %s -- \n\n', modelpath_ );

end
