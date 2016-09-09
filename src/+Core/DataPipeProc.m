classdef DataPipeProc < handle
    %% identification training data creation pipeline processor
    %
    
    %% --------------------------------------------------------------------
    properties (Access = protected, Transient)
        data;
    end
    properties (SetAccess = protected, Transient)
        dataFileProcessor;
        fileListOverlay;
    end
    
    %% --------------------------------------------------------------------
    methods (Access = public)
        
        function obj = DataPipeProc( dataFileProc )
            if ~isa( dataFileProc, 'Core.IdProcInterface' )
                error( 'dataFileProc must be of type Core.IdProcInterface.' );
            end
            obj.dataFileProcessor = dataFileProc;
        end
        %% ----------------------------------------------------------------

        function init( obj )
            obj.dataFileProcessor.init();
        end
        %% ----------------------------------------------------------------

        function connectData( obj, data )
            obj.data = data;
            obj.fileListOverlay =  true( 1, length( obj.data(:) ) ) ;
        end
        %% ----------------------------------------------------------------

        function connectToOutputFrom( obj, outputtingProc )
            if ~isa( outputtingProc, 'Core.DataPipeProc' )
                error( 'outputtingProc must be of type Core.DataPipeProc' );
            end
            obj.dataFileProcessor.setInputProc( ...
                outputtingProc.dataFileProcessor.getOutputObject() );
        end
        %% ----------------------------------------------------------------

        function checkDataFiles( obj, otherOverlay )
            fprintf( '\nChecking file list: %s\n%s\n', ...
                     obj.dataFileProcessor.procName, ...
                     repmat( '=', 1, 20 + numel( obj.dataFileProcessor.procName ) ) );
            if (nargin > 1) && ~isempty( otherOverlay ) && ...
                    (length( otherOverlay ) == length( obj.data(:) ))
                obj.fileListOverlay = otherOverlay;
            else
                obj.fileListOverlay =  true( 1, length( obj.data(:) ) ) ;
            end
            datalist = obj.data(:)';
%             obj.dataFileProcessor.getSingleProcessCacheAccess();
%           singleProcessCacheAccess probably not necessary and slows down multi processes
            obj.dataFileProcessor.setDirectCacheSave( false );
            for ii = 1 : length( datalist )
                if ~obj.fileListOverlay(ii), continue; end
                dataFile = datalist(ii);
                fprintf( '%s\n', dataFile.fileName );
                fileHasBeenProcessed = ...
                    obj.dataFileProcessor.hasFileAlreadyBeenProcessed( dataFile.fileName );
                obj.fileListOverlay(ii) = ~fileHasBeenProcessed;
            end
            fprintf( '..' );
            obj.dataFileProcessor.saveCacheDirectory();
            obj.dataFileProcessor.setDirectCacheSave( true );
%             obj.dataFileProcessor.releaseSingleProcessCacheAccess();
            fprintf( ';\n' );
        end
        %% ----------------------------------------------------------------

        function run( obj )
            errs = {};
            fprintf( '\nRunning: %s\n%s\n', ...
                     obj.dataFileProcessor.procName, ...
                     repmat( '=', 1, 9 + numel( obj.dataFileProcessor.procName ) ) );
            datalist = obj.data(:)';
            datalist = datalist(obj.fileListOverlay);
            ndf = numel( datalist );
            dfii = 1;
            for dataFile = datalist(randperm(length(datalist)))'
                if dfii == 1 % with the first file, caches of wrapped procs often update
                    obj.dataFileProcessor.getSingleProcessCacheAccess();
                    obj.dataFileProcessor.setDirectCacheSave( false );
                end
                fprintf( '%s << (%d/%d) -- %s\n', ...
                           obj.dataFileProcessor.procName, dfii, ndf, dataFile.fileName );
                try
                    obj.dataFileProcessor.processSaveAndGetOutput( dataFile.fileName );
                catch err
                    if any( strcmpi( err.identifier, ...
                                            {'MATLAB:load:couldNotReadFile', ...
                                             'MATLAB:load:unableToReadMatFile'} ...
                                   ) )
                        errs{end+1} = err;
                        warning( err.message );
                    elseif any( strcmpi( err.identifier, ...
                                            {'AMLTTP:dataprocs:cacheFileCorrupt'} ...
                                   ) )
                        delete( err.message ); % err.msg contains corrupt cache file name
                        erpl.message = ['deleted corrupt cache file: ' err.message];
                        errs{end+1} = erpl;
                    else
                        rethrow( err );
                    end
                end
                if dfii == 1
                    obj.dataFileProcessor.saveCacheDirectory();
                    obj.dataFileProcessor.setDirectCacheSave( true );
                    obj.dataFileProcessor.releaseSingleProcessCacheAccess();
                end
                dfii = dfii + 1;
                fprintf( '\n' );
            end
            obj.dataFileProcessor.saveCacheDirectory();
            fprintf( '..;\n' );
            if numel( errs ) > 0
                cellfun(@(c)(warning(c.message)), errs);
                error( 'AMLTTP:dataprocs:fileErrors', ...
                       'errors occured with the %s dataPipeProc filehandling', ...
                       obj.dataFileProcessor.procName );
            end
        end
        %% ----------------------------------------------------------------

    end
    
    %% --------------------------------------------------------------------
    methods (Access = private)
        
    end
    
end

