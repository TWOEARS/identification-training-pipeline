function trainAndTestSegmented( modelPath )

addPathsIfNotIncluded( cleanPathFromRelativeRefs( [pwd '/..'] ) ); 
startAMLTTP();
addPathsIfNotIncluded( {...
    cleanPathFromRelativeRefs( [pwd '/../../segmentation-training-pipeline/src'] ), ... 
    cleanPathFromRelativeRefs( [pwd '/../../segmentation-training-pipeline/external/data-hash'] ), ...
    cleanPathFromRelativeRefs( [pwd '/../../segmentation-training-pipeline/external/yaml-matlab'] ) ...
    } );
segmModelFileName = '70c4feac861e382413b4c4bfbf895695.mat';
mkdir( fullfile( db.tmp, 'learned_models', 'SegmentationKS' ) );
copyfile( ['./' segmModelFileName], ...
          fullfile( db.tmp, 'learned_models', 'SegmentationKS', segmModelFileName ), ...
          'f' );

brirs = { ...
    'impulse_responses/twoears_kemar_adream/TWOEARS_KEMAR_ADREAM_pos1.sofa'; ...
    'impulse_responses/twoears_kemar_adream/TWOEARS_KEMAR_ADREAM_pos2.sofa'; ...
    'impulse_responses/twoears_kemar_adream/TWOEARS_KEMAR_ADREAM_pos3.sofa'; ...
    'impulse_responses/twoears_kemar_adream/TWOEARS_KEMAR_ADREAM_pos4.sofa'; ...
    };

classes = {{'alarm'},{'baby'},{'femaleSpeech'},{'fire'},{'crash'},{'dog'},...
           {'engine'},{'footsteps'},{'knock'},{'phone'},{'piano'},...
           {'maleSpeech'},{'femaleScream','maleScream'}};
for ii = 1 : numel( classes )
    labelCreators{ii,1} = 'LabelCreators.MultiEventTypeLabeler'; %#ok<AGROW>
    labelCreators{ii,2} = {'types', classes(ii), ...
                           'negOut', 'rest', ...
                           'removeUnclearBlocks', 'time-wise',...
                           'segIdTargetSrcFilter', [1,1]}; %#ok<AGROW> % target sounds only on source 1
end

%% train

if nargin < 1 || isempty( modelPath )
    
ll = 3;
    
pipe = TwoEarsIdTrainPipe();
pipe.ksWrapper = DataProcs.SegmentKsWrapper( ...
    'SegmentationTrainerParameters5.yaml', ...
    'useDnnLocKs', false, ...
    'useNsrcsKs', false, ...
    'segSrcAssignmentMethod', 'minDistance', ...
    'varAzmSigma', 0, ...
    'nsrcsBias', 0, ...
    'nsrcsRndPlusMinusBias', 0 );
pipe.featureCreator = FeatureCreators.FeatureSet5Blockmean();
pipe.labelCreator = feval( labelCreators{ll,1}, labelCreators{ll,2}{:} );
pipe.modelCreator = ModelTrainers.GlmNetLambdaSelectTrainer( ...
...%    'performanceMeasure', @PerformanceMeasures.ImportanceWeightedSquareBalancedAccuracy, ...
    'maxDataSize', 1000, ...
    'dataSelector', DataSelectors.BAC_NPP_NS_Selector(), ...
    'importanceWeighter', ImportanceWeighters.BAC_Weighter(), ...
    'cvFolds', 4, ...
    'alpha', 0.99 );
pipe.modelCreator.verbose( 'on' );

pipe.trainset = 'learned_models/IdentityKS/trainTestSets/NIGENS160807_miniMini_TrainSet_1.flist';
pipe.setupData();

sc(1) = SceneConfig.SceneConfiguration();
sc(1).addSource( SceneConfig.BRIRsource( ...
        brirs{4}, 'speakerId', 2, ...
        'data', SceneConfig.FileListValGen( 'pipeInput' ) )...
        );
sc(1).addSource( SceneConfig.BRIRsource( ...
        brirs{4}, 'speakerId', 1, ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.trainSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 )  ),...
    'snr', SceneConfig.ValGen( 'manual', 10 ),...
    'loop', 'randomSeq' );
sc(1).addSource( SceneConfig.BRIRsource( ...
        brirs{4}, 'speakerId', 4, ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.trainSet('fileLabel',{{'type',{'baby'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0.75 )  ),...
    'snr', SceneConfig.ValGen( 'manual', -10 ),...
    'loop', 'randomSeq' );
sc(1).setBRIRheadOrientation( 0.2 );
sc(2) = SceneConfig.SceneConfiguration();
sc(2).addSource( SceneConfig.BRIRsource( ...
        brirs{1}, 'speakerId', 2, ...
        'data', SceneConfig.FileListValGen( 'pipeInput' ) )...
        );
sc(2).addSource( SceneConfig.BRIRsource( ...
        brirs{1}, 'speakerId', 3, ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.trainSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 )  ),...
    'snr', SceneConfig.ValGen( 'manual', 10 ),...
    'loop', 'randomSeq' );
sc(2).setBRIRheadOrientation( 0.5 );
pipe.init( sc, 'hrir', [], 'fs', 16000, 'loadBlockAnnotations', true, ...
           'sceneCfgDataUseRatio', 0.5, 'dataSelector', DataSelectors.BAC_NPP_NS_Selector() );

% pipeInputAll = pipe.pipeline.trainSet(:,'fileName');
% pipeInputCurrentClass = pipe.pipeline.trainSet('fileLabel',{{'type',classes{ll}}},'fileName');
% pipeInputFilter = cellfun( @(c)(any( strcmp( c, pipeInputCurrentClass ) )), pipeInputAll );
modelPath = pipe.pipeline.run( 'modelName', 'segmModel', 'modelPath', 'test_segmented' );%,...
                               %'filterPipeInput', pipeInputFilter, 'debug', true  );

fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

end

%% test

pipe = TwoEarsIdTrainPipe();
pipe.ksWrapper = DataProcs.SegmentKsWrapper( ...
    'SegmentationTrainerParameters5.yaml', ...
    'useDnnLocKs', false, ...
    'useNsrcsKs', false, ...
    'segSrcAssignmentMethod', 'minPermutedDistance', ...
    'varAzmSigma', 0, ...
    'nsrcsBias', 0, ...
    'nsrcsRndPlusMinusBias', 0 );
pipe.featureCreator = FeatureCreators.FeatureSet5Blockmean();
babyLabeler = LabelCreators.MultiEventTypeLabeler( 'types', {{'baby'}}, 'negOut', 'rest', ...
                           'removeUnclearBlocks', 'time-wise',...
                           'segIdTargetSrcFilter', [1,1] ); % target sounds only on source 1 );
pipe.labelCreator = babyLabeler;
pipe.modelCreator = ModelTrainers.LoadModelNoopTrainer( ...
    [pwd filesep 'test_segmented/segmModel.model.mat'], ...
    'performanceMeasure', @PerformanceMeasures.BAC );
pipe.modelCreator.verbose( 'on' );

pipe.testset = 'learned_models/IdentityKS/trainTestSets/NIGENS160807_miniMini_TestSet_1.flist';
pipe.setupData();

sc(1) = SceneConfig.SceneConfiguration();
sc(1).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( 'pipeInput' ), ...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', -45 ) )  );
sc(1).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.testSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', +45 )  ),...
    'snr', SceneConfig.ValGen( 'manual', 10 ),...
    'loop', 'randomSeq' );
sc(1).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.testSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', +135 )  ),...
    'snr', SceneConfig.ValGen( 'manual', -10 ),...
    'loop', 'randomSeq' );
% sc(2) = SceneConfig.SceneConfiguration();
% sc(2).addSource( SceneConfig.PointSource( ...
%         'data', SceneConfig.FileListValGen( 'pipeInput' ), ...
%         'azimuth', SceneConfig.ValGen( 'manual', -45 ) )  );
% sc(2).addSource( SceneConfig.PointSource( ...
%         'data', SceneConfig.FileListValGen( ...
%                pipe.pipeline.testSet('fileLabel',{{'type',{'baby'}}},'fileName') ),...
%         'offset', SceneConfig.ValGen( 'manual', 0 ), ...
%         'azimuth', SceneConfig.ValGen( 'manual', +45 )  ),...
%     'snr', SceneConfig.ValGen( 'manual', 10 ),...
%     'loop', 'randomSeq' );
% sc(2).addSource( SceneConfig.DiffuseSource( ...
%         'offset', SceneConfig.ValGen( 'manual', 0 )  ),...
%     'snr', SceneConfig.ValGen( 'manual', 0 ),...
%     'loop', 'randomSeq' );
pipe.init( sc, 'fs', 16000 );%, 'stopAfterProc', 5 );

[modelPath,~,testPerfresults] = ...
             pipe.pipeline.run( 'modelName', 'segmModel', 'modelPath', 'test_segmented' );%,...
%              'runOption', 'rewriteCache', 'startWithProc', 4 );

fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

%% analysis

% resc = RescSparse( 'uint32', 'uint8' );
resct = RescSparse( 'uint32', 'uint8' );
resct2 = RescSparse( 'uint32', 'uint8' );
    
% profile on

% filesema = setfilesemaphore( 'test.mat' );
% if exist( 'test.mat', 'file' )
%     load( 'test.mat' );
% end
% removefilesemaphore( filesema );

scp = struct('nSources',{3},'headPosIdx',{0},'ambientWhtNoise',{1},'whtNoiseSnr',{8});
scp.id = 1;
[~,resct,resct2,rescDescr] = analyzeBlockbased( [], resct, resct2, testPerfresults, scp, true, 'classIdx', 2, 'dd', 2 );

% filesema = setfilesemaphore( 'test.mat' );
% if exist( 'test.mat', 'file' )
%     fileupdate = load( 'test.mat' );
% %     [data,dataIdxs] = fileupdate.resc.getRowIndexed( 1:size( fileupdate.resc.dataIdxs, 1 ) );
% %     dataIdxs(:,1) = dataIdxs(:,1)+1;
% %     fileupdate.resc = fileupdate.resc.addData( dataIdxs, data );
%     fprintf( ':' );
%     resc = syncResults2( resc, fileupdate.resc, 2, 1 );
%     fprintf( ':' );
%     resct = syncResults2( resct, fileupdate.resct, 2, 1 );
%     fprintf( ':' );
% end
% save( 'test.mat', ...
%       'resc','resct', ...
%       '-v7.3' );
% fprintf( ';\n' );
% removefilesemaphore( filesema );

% profile viewer

% [sens,spec] = getPerformanceDecorr( resc, [3], [] );
% [senst,spect] = getPerformanceDecorr( resct, [3], [] );
% [senst2,spect2] = getPerformanceDecorr( resct2, [3], [] );

end
