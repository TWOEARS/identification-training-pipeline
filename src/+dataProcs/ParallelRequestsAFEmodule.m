classdef ParallelRequestsAFEmodule < dataProcs.IdProcWrapper
    
    %% --------------------------------------------------------------------
    properties (SetAccess = private)
        individualAfeProcs;
        fs;
        afeRequests;
        indivFiles;
        currentNewAfeRequestsIdx;
        currentNewAfeProc;
        prAfeDepProducer;
    end
    
    %% --------------------------------------------------------------------
    methods (Static)
    end
    
    %% --------------------------------------------------------------------
    methods (Access = public)
        
        function obj = ParallelRequestsAFEmodule( fs, afeRequests )
            for ii = 1:length( afeRequests )
                indivProcs{ii} = dataProcs.AuditoryFEmodule( fs, afeRequests(ii) );
            end
            for ii = 2:length( afeRequests )
                indivProcs{ii}.cacheDirectory = indivProcs{1}.cacheDirectory;
            end
            obj = obj@dataProcs.IdProcWrapper( indivProcs, false );
            obj.individualAfeProcs = indivProcs;
            obj.afeRequests = afeRequests;
            obj.fs = fs;
            obj.prAfeDepProducer = dataProcs.AuditoryFEmodule( fs, afeRequests );
        end
        %% ----------------------------------------------------------------

        function process( obj, wavFilepath )
            newAfeRequests = {};
            newAfeRequestsIdx = [];
            for ii = 1 : numel( obj.individualAfeProcs )
                afePartProcessed = ...
                    obj.individualAfeProcs{ii}.hasFileAlreadyBeenProcessed( wavFilepath );
                if ~afePartProcessed
                    newAfeRequests(end+1) = obj.afeRequests(ii);
                    newAfeRequestsIdx(end+1) = ii;
                end
            end
            if ~isempty( newAfeRequestsIdx )
                if ~isequal( newAfeRequestsIdx, obj.currentNewAfeRequestsIdx )
                    obj.currentNewAfeProc = ...
                                     dataProcs.AuditoryFEmodule( obj.fs, newAfeRequests );
                    obj.currentNewAfeProc.setInputProc( obj.inputProc );
                    obj.currentNewAfeProc.cacheSystemDir = obj.cacheSystemDir;
                    obj.currentNewAfeProc.soundDbBaseDir = obj.soundDbBaseDir;
                    obj.currentNewAfeRequestsIdx = newAfeRequestsIdx;
                end
                obj.currentNewAfeProc.process( wavFilepath );
                for jj = 1 : numel( newAfeRequestsIdx )
                    ii = newAfeRequestsIdx(jj);
                    obj.individualAfeProcs{ii}.output = obj.currentNewAfeProc.output;
                    obj.individualAfeProcs{ii}.output.afeData = ...
                                 containers.Map( 'KeyType', 'int32', 'ValueType', 'any' );
                    obj.individualAfeProcs{ii}.output.afeData(1) = ...
                                                 obj.currentNewAfeProc.output.afeData(jj);
                    obj.individualAfeProcs{ii}.saveOutput( wavFilepath );
                end
            end
            for ii = 1 : numel( obj.individualAfeProcs )
                obj.indivFiles{ii} = ...
                              obj.individualAfeProcs{ii}.getOutputFilepath( wavFilepath );
            end
        end
        %% ----------------------------------------------------------------
        
        function afeDummy = makeDummyData ( obj )
            afeDummy.afeData = obj.prAfeDepProducer.makeAFEdata( rand( obj.fs/10, 2 ) );
            afeDummy.annotations = [];
        end
        %% ----------------------------------------------------------------

        % override of dataProcs.IdProcWrapper's method
        function outObj = getOutputObject( obj )
            outObj = getOutputObject@core.IdProcInterface( obj );
        end
        %% -------------------------------------------------------------------------------

        % override of dataProcs.IdProcInterface's method
        function out = loadProcessedData( obj, wavFilepath )
            tmpOut = loadProcessedData@core.IdProcInterface( obj, wavFilepath );
            obj.indivFiles = tmpOut.indivFiles;
            try
                out = obj.getOutput;
            catch err
                if strcmp( 'PRAFEM.FileCorrupt', err.msgIdent )
                    err( '%s \n%s corrupt -- delete and restart.', ...
                         err.msg, obj.getOutputFilepath( wavFilepath ) );
                else
                    rethrow( err );
                end
            end
        end
        %% -------------------------------------------------------------------------------
        
    end

    %% --------------------------------------------------------------------
    methods (Access = protected)
        
        % override of dataProcs.IdProcWrapper's method
        function outputDeps = getInternOutputDependencies( obj )
            afeDeps = obj.prAfeDepProducer.getInternOutputDependencies.afeParams;
            outputDeps.afeParams = afeDeps;
        end
        %% ----------------------------------------------------------------

        % override of dataProcs.IdProcInterface's method
        function out = getOutput( obj )
            out.afeData = containers.Map( 'KeyType', 'int32', 'ValueType', 'any' );
            for ii = 1 : numel( obj.indivFiles )
                if ~exist( obj.indivFiles{ii}, 'file' )
                    error( 'PRAFEM.FileCorrupt', '%s not found.', obj.indivFiles{ii} );
                end
                tmp = load( obj.indivFiles{ii} );
                out.afeData(ii) = tmp.afeData(1);
            end
            out.annotations = tmp.annotations; % if individual AFE modules produced
                                               % individual annotations, they would have
                                               % to be joined here
    end
        %% ----------------------------------------------------------------
        
        % override of dataProcs.IdProcInterface's method
        function out = save( obj, wavFilepath, ~ )
            tmpOut.indivFiles = obj.indivFiles;
            out = save@core.IdProcInterface( obj, wavFilepath, tmpOut ); 
        end
        %% -------------------------------------------------------------------------------

    end
    
    %% --------------------------------------------------------------------
    methods (Access = private)
    end
    
end
