clearAllButBreakpoints;

startTwoEars( '../../src/identificationTraining/identTraining_repos.xml' );

featureCreator = featureCreators.FeatureSet1Blockmean();

modelCreator = modelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @performanceMeasures.BAC2, ...
    'cvFolds', 7, ...
    'alpha', 0.99 );

modelPath = idtrainCleanAzmVar( ...
    'speech', ...
    'trainTestSets/IEEE_AASP_75pTrain_TrainSet_1.flist', ...
    featureCreator, modelCreator, 0 );

modelPath = idtestCleanAzmVar( ...
    'speech', ...
    'trainTestSets/IEEE_AASP_75pTrain_TestSet_1.flist', ...
    modelPath, 0, true );

disp( 'Training with 0 deg azm, Testing with 0 deg azm. Press key to continue' );
pause

modelPath = idtestCleanAzmVar( ...
    'speech', ...
    'trainTestSets/IEEE_AASP_75pTrain_TestSet_1.flist', ...
    modelPath, 90, true );

disp( 'Training with 0 deg azm, Testing with 90 deg azm.' );
