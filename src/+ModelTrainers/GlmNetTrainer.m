classdef GlmNetTrainer < ModelTrainers.Base & Parameterized
    
    %% --------------------------------------------------------------------
    properties (SetAccess = {?Parameterized})
        model;
        alpha;
        family;
        nLambda;
        lambda;
    end

    %% --------------------------------------------------------------------
    methods

        function obj = GlmNetTrainer( varargin )
            pds{1} = struct( 'name', 'performanceMeasure', ...
                             'default', @PerformanceMeasures.BAC2, ...
                             'valFun', @(x)(isa( x, 'function_handle' )), ...
                             'setCallback', @(ob, n, o)(ob.setPerformanceMeasure( n )) );
            pds{2} = struct( 'name', 'alpha', ...
                             'default', 1, ...
                             'valFun', @(x)(isfloat(x) && x >= 0 && x <= 1.0) );
            pds{3} = struct( 'name', 'family', ...
                             'default', 'binomial', ...
                             'valFun', @(x)(ischar(x) && any(strcmpi(x, ...
                                                                     {'binomial',...
                                                                      'multinomial'}))) );
            pds{4} = struct( 'name', 'nLambda', ...
                             'default', 100, ...
                             'valFun', @(x)(rem(x,1) == 0 && x >= 0) );
            pds{5} = struct( 'name', 'lambda', ...
                             'default', [], ...
                             'valFun', @(x)(isempty(x) || isfloat(x)) );
            pds{6} = struct( 'name', 'maxDataSize', ...
                             'default', inf, ...
                             'valFun', @(x)(isinf(x) || (rem(x,1) == 0 && x > 0)) );
            obj = obj@Parameterized( pds );
            obj.setParameters( true, varargin{:} );
        end
        %% ----------------------------------------------------------------

        function buildModel( obj, x, y )
            glmOpts.weights = obj.setDataWeights( y );
            obj.model = Models.GlmNetModel();
            x(isnan(x)) = 0;
            x(isinf(x)) = 0;
            xScaled = obj.model.scale2zeroMeanUnitVar( x, 'saveScalingFactors' );
            clear x;
            glmOpts.alpha = obj.alpha;
            glmOpts.nlambda = obj.nLambda;
            if ~isempty( obj.lambda )
                glmOpts.lambda = obj.lambda;
            end
            verboseFprintf( obj, 'GlmNet training with alpha=%f\n', glmOpts.alpha );
            verboseFprintf( obj, '\tsize(x) = %dx%d\n', size(xScaled,1), size(xScaled,2) );
            obj.model.model = glmnet( xScaled, y, obj.family, glmOpts );
            verboseFprintf( obj, '\n' );
        end
        %% ----------------------------------------------------------------

    end
    
    %% --------------------------------------------------------------------
    methods (Access = protected)
        
        function model = giveTrainedModel( obj )
            model = obj.model;
        end
        %% ----------------------------------------------------------------
        
        function wp = setDataWeights( obj, y )
            labels = unique( y );
            wp = ones( size(y) );
            for ii = 1 : numel( labels )
                labelShare = sum( y == labels(ii) ) / numel( y );
                labelWeight = 1 / labelShare;
                wp(y==labels(ii)) = labelWeight;
            end
        end
        %% ----------------------------------------------------------------
        
    end
    
end