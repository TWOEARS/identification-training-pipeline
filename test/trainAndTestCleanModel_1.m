clearAllButBreakpoints;

startTwoEars( '../../src/identificationTraining/identTraining_repos.xml' );

featureCreator = featureCreators.FeatureSet1Blockmean();
% featureCreator = featureCreators.FeatureSet1VarBlocks();

modelCreator = modelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @performanceMeasures.BAC2, ...
    'cvFolds', 7, ...
    'alpha', 0.99 );
% modelCreator = modelTrainers.SVMmodelSelectTrainer( ...
%     'performanceMeasure', @performanceMeasures.BAC2, ...
%     'hpsSearchBudget', 6, ...
%     'hpsCvFolds', 6, ...
%     'hpsRefineStages', 0, ...
%     'hpsMaxDataSize', 11000 );

modelPath = idtrainClean( 'speech', ...
                          'trainTestSets/IEEE_AASP_75pTrain_TrainSet_1.flist', ...
                          featureCreator, modelCreator );
% modelPath = idtrainClean( 'baby', 'trainTestSets/trainSet_miniMini1.flist', ...
%                           featureCreator, modelCreator );

modelPath = idtestClean( 'speech', 'trainTestSets/IEEE_AASP_75pTrain_TestSet_1.flist', modelPath );
% modelPath = idtestClean( 'baby', 'trainTestSets/testSet_miniMini1.flist', modelPath );

fprintf( ' -- Model is saved at %s -- \n', modelPath );