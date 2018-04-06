classdef FullStreamIdProbStatsIntegrated < FeatureCreators.BlackboardDepFeatureCreator
    %FULLSTREAMIDPROBSTATS5ABLOCKMEAN Summary of this class goes here
    %   Detailed explanation goes here
    
    %% --------------------------------------------------------------------
    properties (SetAccess = private)
        integratedFC;
        idProbDeltaLevels = 2;
    end
    
    %% --------------------------------------------------------------------
    methods (Static)
    end
    
    %% --------------------------------------------------------------------
    methods (Access = public)
        
        function obj = FullStreamIdProbStatsIntegrated( featureCreator )
            obj = obj@FeatureCreators.BlackboardDepFeatureCreator();
            obj.integratedFC = featureCreator;
        end
        
        %% ----------------------------------------------------------------
        function [featureSignalVal, fList] = blackboardVal2FeatureSignalVal( ~, val )
            % turns one sample of blackboard data to a sample that can be
            % stored in a featureSignal
            idHyp = val.('identityHypotheses');
            featureSignalVal = [idHyp.p];
            fList = {idHyp.label};
        end
        
        %% ----------------------------------------------------------------
        
        function afeRequests = getAFErequests( obj )
            afeRequests = obj.integratedFC.getAFErequests();
        end
        %% -------------------------------------------------------------------------------
        
        % override
        function process( obj, wavFilepath )
            inData = obj.loadInputData( wavFilepath );
            obj.blockAnnotations = inData.blockAnnotations;
            obj.integratedFC.blockAnnotations = inData.blockAnnotations;
            obj.x = [];
            for ii = 1 : numel( inData.afeBlocks )
                obj.baIdx = ii;
                obj.integratedFC.baIdx = ii;
                obj.afeData = inData.afeBlocks{ii};
                obj.integratedFC.afeData = inData.afeBlocks{ii};
                xd = obj.constructVector();
                if isempty( obj.x )
                    obj.x = zeros( numel( inData.afeBlocks ), size( xd{1}, 1 ), size( xd{1}, 2 ) );
                end
                obj.x(ii,:,:) = xd{1};
                fprintf( '.' );
                if obj.descriptionBuilt, continue; end
                obj.description = xd{2};
                obj.descriptionBuilt = true;
            end
        end
        %% ----------------------------------------------------------------
        
        function x = constructVector( obj )
            % constructVector for each feature: compress, scale, average
            %   over left and right channels, construct individual feature names
            %   returned flattened feature vector for entire block
            %   The AFE data is indexed according to the order in which the requests
            %   where made
            %
            %   See getAFErequests
            
            x = obj.integratedFC.constructVector();
                        
            % afeIdx ? : idProbs
            idProbsIndex = numel(obj.integratedFC.getAFErequests()) + 1;            
            idProbs = obj.makeBlockFromAfe( idProbsIndex, [], ...
                @(a)(a.Data), ...
                {@(a)('idProbs')}, ...
                {'t'}, ...
                {@(a)(strcat('class-', a.fList))});
            
            plainProbs = obj.reshape2featVec(idProbs);
            x = obj.concatFeats( x, plainProbs );
            
            moments = obj.block2feat( idProbs, ...
                @(b)(lMomentAlongDim( b, [1,2], 1, true )), ...
                2, @(idxs)(sort([idxs idxs idxs])),...
                {{'1.LMom',@(idxs)(idxs(1:2:end))},...
                {'2.LMom',@(idxs)(idxs(2:2:end))}} );
            x = obj.concatFeats( x, moments );
            
            for ii = 1:obj.idProbDeltaLevels
                idProbs = obj.transformBlock( idProbs, 1, ...
                    @(b)(b(2:end,:) - b(1:end-1,:)), ...
                    @(idxs)(idxs(1:end-1)),...
                    {[num2str(ii) '.delta']} );
                delta = obj.block2feat( idProbs, ...
                    @(b)(lMomentAlongDim( b, [1,2], 1, true )), ...
                    2, @(idxs)(sort([idxs idxs])),...
                    {{'1.LMom',@(idxs)(idxs(1:2:end))},...
                    {'2.LMom',@(idxs)(idxs(2:2:end))}} );
                x = obj.concatFeats( x, delta );
            end
            
        end
        %% ----------------------------------------------------------------
        
        function outputDeps = getFeatureInternOutputDependencies( obj )
            outputDeps = obj.integratedFC.getFeatureInternOutputDependencies();
            classInfo = metaclass( obj );
            [classname1, classname2] = strtok( classInfo.Name, '.' );
            if isempty( classname2 ), outputDeps.featureProc = strcat( classname1 + outputDeps.featureProc );
            else outputDeps.featureProc = strcat(classname2(2:end) , outputDeps.featureProc); end
            outputDeps.idProbDeltaLevels = 2;
            outputDeps.v = 1;
        end
    end
    
end

