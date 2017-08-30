function STLComparison(varargin)
addPathsIfNotIncluded( cleanPathFromRelativeRefs( [pwd '/..'] ) ); 
startAMLTTP();

% parse input
p = inputParser;
addParameter(p,'scModelFile', './Results_B/SCModel_b100_beta0.4.mat', ... 
    @(x)( ischar(x) && exist(x, 'file') ) );

addParameter(p,'gamma', 0.4, @(x)(isfloat(x) && isvector(x)) );

addParameter(p,'trainingSetPortions', 0.1:0.1:1, ... 
    @(x)(isfloat(x) && isvector(x) && all(x>0) && all(x<=1)) );

addParameter(p,'labels', {'alarm', 'baby', 'femaleSpeech', 'fire'}, ...
   @(x)(iscell(x) && ~isempty(x)));

addParameter(p, 'resultsFile', ...
    './STLComparison/STLComparison_results.mat', ...
    @(x) ischar(x) && exist(x, 'file'))

addParameter(p, 'maxDataSize', 20000,...
    @(x)(isinf(x) || (rem(x,1) == 0 && x > 0)) );

parse(p, varargin{:});

% set parameters
scModelFile         = p.Results.scModelFile;
gamma               = p.Results.gamma;
trainingSetPortions = p.Results.trainingSetPortions;
labels              = p.Results.labels;
resultsFile         = p.Results.resultsFile;
maxDataSize         = p.Results.maxDataSize;
        
if isempty(scModelFile)
    error(['You have to pass a valid directory <scModelDir> to ' ...
        ' STLComparison']);
end

data = load(scModelFile);
if ~isa(data.model, 'Models.SparseCodingModel')
     error(['You have to pass a file <scModelFile> with a valid' ...
        ' model Models.SparseCodingModel to STLComparison']);
end    


%  trainSet = {'learned_models\IdentityKS\trainTestSets\IEEE_AASP_75pTrain_TrainSet_1.flist', ...
%      'learned_models\IdentityKS\trainTestSets\IEEE_AASP_75pTrain_TrainSet_2.flist'};
%  
%  testSet = {'learned_models\IdentityKS\trainTestSets\IEEE_AASP_75pTrain_TestSet_1.flist', ...
%      'learned_models\IdentityKS\trainTestSets\IEEE_AASP_75pTrain_TestSet_2.flist'};

trainSet = {'learned_models/IdentityKS/trainTestSets/NIGENS160807_75pTrain_TrainSet_1.flist', ...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_75pTrain_TrainSet_2.flist', ...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_75pTrain_TrainSet_3.flist', ...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_75pTrain_TrainSet_4.flist'};
        
testSet = {'learned_models/IdentityKS/trainTestSets/NIGENS160807_75pTrain_TestSet_1.flist', ...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_75pTrain_TestSet_2.flist', ...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_75pTrain_TestSet_3.flist', ...
            'learned_models/IdentityKS/trainTestSets/NIGENS160807_75pTrain_TestSet_4.flist'};
        
assert(length(trainSet) == length(testSet), ...
        'Lists of training and test sets must have same length');

scModel = data.model;

modelTrainer = ModelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @PerformanceMeasures.BAC2, ...
    'cvFolds', 4, ...
    'alpha', 0.99, ...
    'maxDataSize', maxDataSize);

addpath('./STLComparison/')

% try to load file with already computed configurations to skip computation 
% of those configurations, else initialise a new variable for the results
if exist(resultsFile, 'file')
    filedata = load(resultsFile);
    results = filedata.results;
else
    results = struct('label', {}, 'portion', 0, 'STLPerformance', [], ...
        'PurePerformance', []);
end

for labelIndex=1:length(labels)
    
    labelCreator = LabelCreators.MultiEventTypeLabeler( ...
        'types', labels(labelIndex), 'negOut', 'rest');
    
    for portionIndex=1:length(trainingSetPortions)        
        for cvIndex=1:length(trainSet)  
            
            % reduce file list to only use the specified portion of files
            file = db.getFile(trainSet{cvIndex});
            trainList = ReduceFileList(file, ... 
                trainingSetPortions(portionIndex));

            % check whether configuration is already entry in results
            entryIdx = find( cellfun(@(x) strcmp(x,labels{labelIndex}), ...
                {results.label}) & ...
                [results.portion] == trainingSetPortions(portionIndex) );

            if isempty(entryIdx)
                % add new configuration entry if not yet in results
                entryIdx = length(results) + 1 ;
                results(entryIdx).label = labels{labelIndex};
                results(entryIdx).portion = ...
                    trainingSetPortions(portionIndex);
                results(entryIdx).STLPerformance = [];
                results(entryIdx).PurePerformance = [];
            end

            % *** STLTEST ***
            % skip computation if entry and corresponding
            % performance already exists
            if length(results(entryIdx).STLPerformance) < cvIndex
                modelPath = 'STLTest';
                modelName = ...
                    sprintf('STLModel_b%d_gamma%g_%s_portion%g_%d', ...
                    size(scModel.B,1), gamma, labels{labelIndex}, ...
                    trainingSetPortions(portionIndex), cvIndex);       

                savedModel = STLTest('scModel', scModel, ...
                        'modelName', modelName, ...
                        'modelPath', modelPath, ...
                        'scGamma', gamma, ...
                        'trainSet', trainList, ...
                        'testSet', testSet{cvIndex}, ...
                        'labelCreator', labelCreator, ...
                        'modelTrainer', modelTrainer);

                savedData = load(savedModel);
                results(entryIdx).STLPerformance(cvIndex) = ...
                    savedData.testPerfresults.performance;

                save(resultsFile, 'results');
            end
            
            % *** STLPureMethodWrapper ***
            % skip computation if entry and corresponding
            % performance already exists
            if length(results(entryIdx).PurePerformance) < cvIndex
                modelPath = 'STLPureMethodWrapper';
                modelName = sprintf(['STLPureMethodWrapperModel_%s_'...
                    'portion%g_%d'], labels{labelIndex}, ...
                    trainingSetPortions(portionIndex), cvIndex);       

                savedModel = STLPureMethodWrapper('modelName', modelName, ...
                        'modelPath', modelPath, ...
                        'trainSet', trainList, ...
                        'testSet', testSet{cvIndex}, ...
                        'labelCreator', labelCreator, ...
                        'modelTrainer', modelTrainer);

                savedData = load(savedModel);
                results(entryIdx).PurePerformance(cvIndex) = ...
                    savedData.testPerfresults.performance;

                save(resultsFile, 'results');
            end
        end
    end
end

cvFold = length(trainSet);
%add means
meanSTL =  mean(reshape([results.STLPerformance]', cvFold, []), 1);
meanSTL = num2cell(meanSTL);
[results(:).meanSTL] = meanSTL{:};

meanPure = mean(reshape([results.PurePerformance]', cvFold, []), 1);
meanPure = num2cell(meanPure);
[results(:).meanPure] = meanPure{:};

%add vars
varSTL =  var(reshape([results.STLPerformance]', cvFold, []), 1);
varSTL = num2cell(varSTL);
[results(:).varSTL] = varSTL{:};

varPure = var(reshape([results.PurePerformance]', cvFold, []), 1);
varPure = num2cell(varPure);
[results(:).varPure] = varPure{:};

save(resultsFile, 'results');

% compute overall results 
overallMeanSTL  = arrayfun( @(x) mean([results([results.portion] == x).meanSTL]), trainingSetPortions);
overallMeanPure = arrayfun( @(x) mean([results([results.portion] == x).meanPure]), trainingSetPortions);

overall.meanSTL  = overallMeanSTL;
overall.meanPure = overallMeanPure;

overallVarSTL  = arrayfun( @(x) var([results([results.portion] == x).meanSTL]), trainingSetPortions);
overallVarPure = arrayfun( @(x) var([results([results.portion] == x).meanPure]), trainingSetPortions);

overall.varSTL  = overallVarSTL;
overall.varPure = overallVarPure;

splitted = strsplit(resultsFile, '_');
overallFile = strcat(splitted{1:end - 1}, '_overall.mat');
save(overallFile, 'overall');
