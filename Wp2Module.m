classdef Wp2Module < IdWp2ProcInterface
    
    %%---------------------------------------------------------------------
    properties (SetAccess = private)
        managerObject;           % WP2 manager object - holds the signal buffer (data obj)
        outputSignals;
        wp2dataObj;
    end
    
    %%---------------------------------------------------------------------
    methods (Static)
    end
    
    %%---------------------------------------------------------------------
    methods (Access = public)
        
        function obj = Wp2Module()
            obj = obj@IdWp2ProcInterface();
        end
        
        function hashMembers = getHashObjects( obj )
            hashMembers = {obj.wp2dataObj.getParameterSummary( obj.managerObject ) };
        end

        %%-----------------------------------------------------------------

        function init( obj, fs, wp2Requests )
            obj.wp2dataObj = dataObject( [], fs, 2, 1 );
            obj.managerObject = manager( obj.wp2dataObj );
            for ii = 1:length( wp2Requests )
                obj.outputSignals{ii} = obj.managerObject.addProcessor( ...
                    wp2Requests{ii}.name, wp2Requests{ii}.params );
            end
        end
        
    end
    
    %%---------------------------------------------------------------------
    methods (Access = protected)
        
        function wp2data = makeWp2Data( obj, earSignals )
            obj.managerObject.reset();
            obj.wp2dataObj.clearData();
            fs = obj.wp2dataObj.signal{1,1}.FsHz;
            for ii = 1:numel( obj.outputSignals )
                outputSig = obj.outputSignals{ii};
                for kk = 1:numel( outputSig )
                    if isa( outputSig, 'cell' )
                        os = outputSig{kk}; 
                    else
                        os = outputSig(kk);
                    end
                    os.setBufferSize( ceil( length( earSignals ) / fs ) );
                end
            end
            % process chunks of 1 second
            for chunkBegin = 1:fs:length(earSignals)
                chunkEnd = min( length( earSignals ), chunkBegin + fs - 1 );
                obj.managerObject.processChunk( earSignals(chunkBegin:chunkEnd,:), 1 );
                fprintf( '.' );
            end
            wp2data = obj.outputSignals;
        end
        
    end

end
