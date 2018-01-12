classdef IdentTrainPipeDataElem < handle
    
    %% -----------------------------------------------------------------------------------
    properties
        fileName;
        x;
        y;
        ysi; % assignment of label to source index
        bIdxs;
        bacfIdxs;
        blockAnnotsCacheFile;
        fileAnnotations = struct;
        blockAnnotations;
        containedIn;
    end
    
    %% -----------------------------------------------------------------------------------
    methods
        
        %% Constructor
        function obj = IdentTrainPipeDataElem( fileName, container )
            if exist( 'fileName', 'var' ), obj.fileName = fileName; end
            if nargin >= 2 && isa( container, 'Core.IdentTrainPipeData' )
                obj.containedIn{1} = container;
            end
        end
        %% -------------------------------------------------------------------------------
        
        function set.fileName( obj, fileName )
            obj.fileName = fileName;
            obj.readFileAnnotations();
        end
        %% -------------------------------------------------------------------------------
        
        function set.containedIn( obj, containers )
            obj.containedIn = uniqueHandles( containers );
        end
        %% -------------------------------------------------------------------------------
        
        function addContainers( obj, containers )
            containers = [obj.containedIn, containers];
            obj.containedIn = containers;
        end
        %% -------------------------------------------------------------------------------

        function fa = getFileAnnotation( obj, aLabel )
            if isfield( obj.fileAnnotations, aLabel )
                fa = obj.fileAnnotations.(aLabel);
            else
                fa = [];
            end
        end
        %% -------------------------------------------------------------------------------
        
        function readFileAnnotations( obj )
            obj.fileAnnotations.type = IdEvalFrame.readEventClass( obj.fileName );
        end
        %% -------------------------------------------------------------------------------

    end
    
    %% -----------------------------------------------------------------------------------
    methods (Static)
        
        function bas = addPPtoBas( bas, y )
            bons = cat( 1, bas.blockOnset );
            bofs = cat( 1, bas.blockOffset );
            pos_bons = bons(y == +1);
            pos_bofs = bofs(y == +1);
            ba_pp = zeros( size( bas ) );
            for ii = 1 : sum( y == +1 )
                ba_pp(bons == pos_bons(ii) & bofs == pos_bofs(ii)) = 1;
            end
            ba_pp = num2cell( ba_pp );
            [bas(:).posPresent] = deal( ba_pp{:} );
        end
        %% -------------------------------------------------------------------------------

    end
    
end