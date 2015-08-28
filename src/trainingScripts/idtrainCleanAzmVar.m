function modelPath = idtrainCleanAzmVar( classname, trainFlist, featureCreator, modelTrainer, azm )

trainpipe = TwoEarsIdTrainPipe();
trainpipe.featureCreator = featureCreator;
trainpipe.modelCreator = modelTrainer;
trainpipe.modelCreator.verbose( 'on' );

trainpipe.trainset = trainFlist;

sc = sceneConfig.SceneConfiguration(); % clean
sc.angleSignal = sceneConfig.ValGen('manual', azm);
trainpipe.setSceneConfig( [sc] ); 

trainpipe.init();
modelPath = trainpipe.pipeline.run( {classname}, 0 );

end

