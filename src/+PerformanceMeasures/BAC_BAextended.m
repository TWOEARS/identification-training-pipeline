classdef BAC_BAextended < PerformanceMeasures.Base
    
    %% --------------------------------------------------------------------
    properties (SetAccess = protected)
        tp;
        fp;
        tn;
        fn;
        sensitivity;
        specificity;
        acc;
        resc_b;
        resc_t;
        resc_t2;
    end
    
    %% --------------------------------------------------------------------
    methods
        
        function obj = BAC_BAextended( yTrue, yPred, varargin )
            obj = obj@PerformanceMeasures.Base( yTrue, yPred, varargin{:} );
        end
        % -----------------------------------------------------------------

        function po = strapOffDpi( obj )
            po = strapOffDpi@PerformanceMeasures.Base( obj );
            po.resc_b = [];
            po.resc_t = [];
            po.resc_t2 = [];
        end
        % -----------------------------------------------------------------
    
        function b = eqPm( obj, otherPm )
            b = obj.performance == otherPm.performance;
        end
        % -----------------------------------------------------------------
    
        function b = gtPm( obj, otherPm )
            b = obj.performance > otherPm.performance;
        end
        % -----------------------------------------------------------------
    
        function d = double( obj )
            for ii = 1 : size( obj, 2 )
                d(ii) = double( obj(ii).performance );
            end
        end
        % -----------------------------------------------------------------
    
        function s = char( obj )
            if numel( obj ) > 1
                warning( 'only returning first object''s performance' );
            end
            s = num2str( obj(1).performance );
        end
        % -----------------------------------------------------------------
    
        function [obj, performance, dpi] = calcPerformance( obj, yTrue, yPred, ~, dpi, testSetIdData )
            dpi.yTrue = yTrue;
            dpi.yPred = yPred;
            tps = yTrue == 1 & yPred > 0;
            tns = yTrue == -1 & yPred < 0;
            fps = yTrue == -1 & yPred > 0;
            fns = yTrue == 1 & yPred < 0;
            obj.tp = sum( tps );
            obj.tn = sum( tns );
            obj.fp = sum( fps );
            obj.fn = sum( fns );
            tp_fn = sum( yTrue == 1 );
            tn_fp = sum( yTrue == -1 );
            if tp_fn == 0
                warning( 'No positive true label.' );
                obj.sensitivity = nan;
            else
                obj.sensitivity = obj.tp / tp_fn;
            end
            if tn_fp == 0
                warning( 'No negative true label.' );
                obj.specificity = nan;
            else
                obj.specificity = obj.tn / tn_fp;
            end
            obj.acc = (obj.tp + obj.tn) / (tp_fn + tn_fp); 
            performance = 0.5 * obj.sensitivity + 0.5 * obj.specificity;
            obj = obj.analyzeBAextended( yTrue, yPred, testSetIdData, dpi.sampleIds );
        end
        % -----------------------------------------------------------------

        function obj = analyzeBAextended( obj, yTrue, yPred, testSetIdData, sampleIds )
            fprintf( 'analyzing BA-extended' );
            obj.resc_b = RescSparse( 'uint32', 'uint8' );
            obj.resc_t = RescSparse( 'uint32', 'uint8' );
            obj.resc_t2 = RescSparse( 'uint32', 'uint8' );
            bapis = cell( numel( testSetIdData.data ), 1 );
            agBapis = cell( numel( testSetIdData.data ), 1 );
            asgns = cell( numel( testSetIdData.data ), 1 );
            agAsgns = cell( numel( testSetIdData.data ), 1 );
            agBapis2 = cell( numel( testSetIdData.data ), 1 );
            agAsgns2 = cell( numel( testSetIdData.data ), 1 );
            blockAnnotsCacheFiles = testSetIdData(:,'blockAnnotsCacheFile');
            [bacfClassIdxs,bacfci_ic] = PerformanceMeasures.BAC_BAextended.getFileIds( blockAnnotsCacheFiles );
            sampleFileIdxs_all = testSetIdData(:,'pointwiseFileIdxs');
            sampleFileIdxs = sampleFileIdxs_all(sampleIds);
            for ii = 1 : numel( testSetIdData.data )
                scp.classIdx = nan;
                scp.fileClassId = bacfClassIdxs(ii);
                scp.fileId = sum( bacfci_ic(1:ii) == bacfci_ic(ii) );
                blockAnnotations_ii = testSetIdData(ii,'blockAnnotations');
                sampleIds_ii = sampleIds(sampleFileIdxs==ii);
                sampleIds_ii = sampleIds_ii - sum( sampleFileIdxs_all <= ii-1 );
                blockAnnotations_ii = blockAnnotations_ii(sampleIds_ii);
                yt_ii = yTrue(sampleFileIdxs==ii,:);
                yp_ii = yPred(sampleFileIdxs==ii,:);
                bacfIdxs_ii = testSetIdData(ii,'bacfIdxs');
                bacfIdxs_ii = bacfIdxs_ii(sampleIds_ii);
                for jj = 1 : numel( blockAnnotsCacheFiles{ii} )
                    scp.id = jj;
                    blockAnnotations = blockAnnotations_ii(bacfIdxs_ii==jj);
                    yt = yt_ii(bacfIdxs_ii==jj);
                    yp = yp_ii(bacfIdxs_ii==jj);
                    if isempty( blockAnnotations ), continue; end
                    [bapis{ii,jj},agBapis{ii,jj},agBapis2{ii,jj},...
                     asgns{ii,jj},agAsgns{ii,jj},agAsgns2{ii,jj}] = ...
                                 PerformanceMeasures.BAC_BAextended.produceBapisAsgns( ...
                                      yt, yp, blockAnnotations,...
                                      scp ); %#ok<*PROPLC>
                end
            end
            asgns = PerformanceMeasures.BAC_BAextended.catAsgns( asgns );
            obj.resc_b = addDpiToResc( obj.resc_b, asgns, cat( 1, bapis{:} ) );
            fprintf( ':' );
            if any( ~cellfun( @isempty, agAsgns ) )
                agAsgns = PerformanceMeasures.BAC_BAextended.catAsgns( agAsgns );
                obj.resc_t = addDpiToResc( obj.resc_t, agAsgns, cat( 1, agBapis{:} ) );
            end
%             fprintf( ':' );
%             if any( ~cellfun( @isempty, agAsgns2 ) )
%                 agAsgns2 = PerformanceMeasures.BAC_BAextended.catAsgns( agAsgns2 );
%                 obj.resc_t2 = addDpiToResc( obj.resc_t2, agAsgns2, cat( 1, agBapis2{:} ) );
%             end
            fprintf( ';' );
            fprintf( '\n' );
        end
        % -----------------------------------------------------------------

    end
    
    %% --------------------------------------------------------------------
    methods (Static)
        
        function asgns = catAsgns( asgns )
            asgns = cat( 1, asgns{:} );
            asgns = {cat( 1, asgns{:,1} ), cat( 1, asgns{:,2} ), ...
                     cat( 1, asgns{:,3} ), cat( 1, asgns{:,4} )};
        end
        % -----------------------------------------------------------------
       
        function [bacfClassIdxs,bacfci_ic] = getFileIds( blockAnnotsCacheFiles )
            bacfiles = cellfun( @(x)(applyIfNempty(x,@(c)(c{1}))), blockAnnotsCacheFiles, 'UniformOutput', false )';
            [~,bacfiles] = cellfun( @(x)(applyIfNempty(x,@fileparts)), bacfiles, 'UniformOutput', false );
            [~,bacfClasses] = cellfun( @(c)( strtok(c,'.') ), bacfiles, 'UniformOutput', false );
            [bacfClasses,~] = cellfun( @(c)( strtok(c,'.') ), bacfClasses, 'UniformOutput', false );
            niClasses = {{'alarm'},{'baby'},{'femaleSpeech'},{'fire'},{'crash'},{'dog'},...
                {'engine'},{'footsteps'},{'knock'},{'phone'},{'piano'},...
                {'maleSpeech'},{'femaleScream','maleScream'},{'general'}};
            bacfClassIdxs = cellfun( ...
                @(x)( find( cellfun( @(c)(any( strcmpi( x, c ) )), niClasses ) ) ), ...
                bacfClasses, 'UniformOutput', false );
            bacfClassIdxs(cellfun(@isempty,bacfClassIdxs)) = {nan};
            bacfClassIdxs = cell2mat( bacfClassIdxs );
            [~,~,bacfci_ic] = unique( bacfClassIdxs );
        end
        % -----------------------------------------------------------------
        
        function [pis,agPis,agPis2,asg,agAsg,agAsg2] = produceBapisAsgns( ...
                                                           yt, yp, blockAnnotations, scp )
            [blockAnnotations, yt, yp, sameTimeIdxs] = findSameTimeBlocks( blockAnnotations, yt, yp );
            [bap, asg] = extractBAparams( blockAnnotations, scp, yp, yt );
            fprintf( '.' );
            if isfield( blockAnnotations, 'estAzm' ) % is segId
                usti = unique( sameTimeIdxs )';
                agBap = bap;
                agBap(numel( usti )+1:end,:) = [];
                agBap(:,2:10) = deal( nanRescStruct );
                agYt = yt;
                agYt(numel( usti )+1:end,:) = [];
                agYp = yp;
                agYp(numel( usti )+1:end,:) = [];
                maxc = 0;
                for bb = 1 : numel( usti )
                    stibb = sameTimeIdxs==usti(bb);
                    sumStibb = sum( stibb );
                    maxc = max( maxc, sumStibb );
                    agBap(bb,1:sumStibb) = bap(stibb);
                    agYt(bb,1:sumStibb) = yt(stibb);
                    agYp(bb,1:sumStibb) = yp(stibb);
                end
                agBap(:,maxc+1:end) = [];
                [agBap3, asg] = aggregateBlockAnnotations3( agBap, agYp, agYt );
%                 [agBap2, agAsg2] = aggregateBlockAnnotations2( agBap, agYp, agYt );
                agAsg2 = [];
                [agBap, agAsg] = aggregateBlockAnnotations( agBap, agYp, agYt );
                agPis = baParams2bapIdxs( agBap );
%                 agPis2 = baParams2bapIdxs( agBap2 );
                agPis2 = [];
                pis = baParams2bapIdxs( agBap3 );
                fprintf( ',' );
            else
                pis = baParams2bapIdxs( bap );
                agPis = [];
                agPis2 = [];
                agAsg = [];
                agAsg2 = [];
            end
        end
        % -----------------------------------------------------------------

        
    end

end

