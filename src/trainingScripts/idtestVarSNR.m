function idtestVarSNR( classname, testFlist, modelPath, SNR )

testpipe = TwoEarsIdTrainPipe();
m = load( fullfile( modelPath, [classname '.model.mat'] ) );
testpipe.featureCreator = m.featureCreator;
testpipe.modelCreator = ...
    modelTrainers.LoadModelNoopTrainer( ...
        @(cn)(fullfile( modelPath, [cn '.model.mat'] )), ...
        'performanceMeasure', @performanceMeasures.BAC2, ...
        'modelParams', struct('lambda', []));
testpipe.modelCreator.verbose( 'on' );

testpipe.testset = testFlist;

sc = sceneConfig.SceneConfiguration();
sc.angleSignal = sceneConfig.ValGen('manual', [0]);
sc.distSignal = sceneConfig.ValGen('manual', [3]);
sc.addOverlay( ...
    sceneConfig.ValGen('random', [0,359.9]), ...
    sceneConfig.ValGen('manual', 3),...
    sceneConfig.ValGen('manual', [SNR]), 'diffuse',...
    sceneConfig.ValGen('set', {'trainingScripts/noise/whtnoise.wav'}), ...
    sceneConfig.ValGen('manual', 0) );
testpipe.setSceneConfig( [sc] ); 

testpipe.init();
testpipe.pipeline.run( {classname}, 0 );

end
