classdef EnergyDependentLabeler < LabelCreators.Base
    % abstract class for labeling blocks that exhibit enough energy in specified sources
    %% -----------------------------------------------------------------------------------
    properties (SetAccess = private)
        sourcesMinEnergy;
        sourceIds;
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Abstract)
        y = labelEnergeticBlock( obj, blockAnnotations )
    end

    %% -----------------------------------------------------------------------------------
    methods
        
        function obj = EnergyDependentLabeler( varargin )
            ip = inputParser;
            ip.addOptional( 'sourcesMinEnergy', -20 );
            ip.addOptional( 'labelBlockSize_s', [] );
            ip.addOptional( 'sourceIds', 1 );
            ip.parse( varargin{:} );
            obj = obj@LabelCreators.Base( 'labelBlockSize_s', ip.Results.labelBlockSize_s );
            obj.sourcesMinEnergy = ip.Results.sourcesMinEnergy;
            obj.sourceIds = ip.Results.sourceIds;
        end
        %% -------------------------------------------------------------------------------

    end
    
    %% -----------------------------------------------------------------------------------
    methods (Access = protected)
        
        function outputDeps = getInternOutputDependencies( obj )
            outputDeps = getInternOutputDependencies@LabelCreators.Base( obj );
            outputDeps.sourcesMinEnergy = obj.sourcesMinEnergy;
            outputDeps.sourceIds = obj.sourceIds;
            outputDeps.v = 1;
        end
        %% -------------------------------------------------------------------------------

        function y = label( obj, blockAnnotations )
            rejectBlock = LabelCreators.EnergyDependentLabeler.isEnergyTooLow( ...
                                  blockAnnotations, obj.sourceIds, obj.sourcesMinEnergy );
            if rejectBlock
                y = NaN;
            else
                y = obj.labelEnergeticBlock( blockAnnotations );
            end
        end
        %% -------------------------------------------------------------------------------
                
    end
    %% -----------------------------------------------------------------------------------
    
    methods (Static)
        
        %% -------------------------------------------------------------------------------
        
        function eTooLow = isEnergyTooLow( blockAnnotations, sourceIds, sourcesMinEnergy )
            eFrames = cellfun( @(e)( e(sourceIds,:) ), ...
                           blockAnnotations.srcEnergy.srcEnergy, 'UniformOutput', false );
            sourcesEnergy  = -log( -mean( cell2mat( eFrames ), 2 ) );
            eTooLow = sum( log( -sourcesMinEnergy ) + sourcesEnergy ) < 0;
        end
        %% -------------------------------------------------------------------------------
        
    end
    
end

        
