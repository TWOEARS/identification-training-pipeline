classdef SparseCodingSelectTrainer < ModelTrainers.HpsTrainer & Parameterized
    % SparseCodingSelectTrainer trainer for a SparseCodingModel
    %   Implements sparse coding for a given input to fit a base with 
    %   sparse activations. This trainer will do a k-fold 
    %   cross-validation to choose the best sparsity factor beta as well 
    %   as the dimension of the base.
    %% --------------------------------------------------------------------
    properties (SetAccess = {?Parameterized})
        hpsBetaRange;       % range of sparsity factors
        hpsNumBasesRange;    % range of dim of base
    end
    
    %% --------------------------------------------------------------------
    methods

        function obj = SparseCodingSelectTrainer( varargin )
            pds{1} = struct( 'name', 'hpsBetaRange', ...
                             'default', [0.3 0.8], ...
                             'valFun', @(x)(isfloat(x) && length(x)==2 && x(1) < x(2)) );
                         
            pds{2} = struct( 'name', 'hpsNumBasesRange', ...
                             'default', [50 150], ...
                             'valFun', @(x)(isinteger(x) && length(x)==2 && x(1) < x(2)) );
            
            obj = obj@Parameterized( pds );
            obj = obj@ModelTrainers.HpsTrainer( varargin{:} );
            
% TODO: add Binit, batch_size, num_iters            
%             obj.setParameters( true, ...
%                 'buildCoreTrainer', @SparseCodingTrainer, ...
%                'hpsCoreTrainerParams', {'BaseInit', 2,}, ...
%                 varargin{:} );
%             obj.setParameters( false, ...
%                 'finalCoreTrainerParams', ...
%                     {'BaseInit', 2,} );
        end
        %% -------------------------------------------------------------------------------
        
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Access = protected)
        
        function hpsSets = getHpsGridSearchSets( obj )
            hpsBetas = linspace( obj.hpsBetaRange(1), ...
                                  obj.hpsBetaRange(2), ...
                                  obj.hpsSearchBudget );
                              
            hpsNumBases = linspace( obj.hpsNumBasesRange(1), ...
                                  obj.hpsNumBasesRange(2), ...
                                  obj.hpsSearchBudget );
                              
            [betaGrid, numBasesGrid] = ndgrid( hpsBetas, hpsNumBases );
            hpsSets = [betaGrid(:), numBasesGrid(:)];
            hpsSets = unique( hpsSets, 'rows' );
            hpsSets = cell2struct( num2cell(hpsSets), {'beta', 'num_bases'}, 2 );
        end
        %% -------------------------------------------------------------------------------
        
        function refinedHpsTrainer = refineGridTrainer( obj, hps )
            refinedHpsTrainer = GlmNetModelSelectTrainer( 'buildCoreTrainer', obj.buildCoreTrainer, ...
                                                          'hpsCoreTrainerParams', obj.hpsCoreTrainerParams, ...
                                                          'finalCoreTrainerParams', obj.finalCoreTrainerParams, ...
                                                          'hpsMaxDataSize', obj.hpsMaxDataSize, ...
                                                          'hpsRefineStages', obj.hpsRefineStages, ...
                                                          'hpsSearchBudget', obj.hpsSearchBudget, ...
                                                          'hpsCvFolds', obj.hpsCvFolds, ...
                                                          'hpsMethod', obj.hpsMethod, ...
                                                          'performanceMeasure', obj.performanceMeasure  );
            best3LogMean = @(fn)(mean( log10( [hps.params(end-2:end).(fn)] ) ));
            
            betaRefinedRange = 10.^getCenteredHalfRange( ...
                log10(obj.hpsBetaRange), best3LogMean('beta') );
            
            numBasesRefinedRange = 10.^getCenteredHalfRange( ...
                log10(obj.hpsNumBasesRange), best3LogMean('num_bases') );
            
            refinedHpsTrainer.setParameters( false, ...
                'hpsBetaRange', betaRefinedRange, ...
                'hpsNumBasesRange', numBasesRefinedRange );
        end
        
        %% -------------------------------------------------------------------------------
        
    end
        
end