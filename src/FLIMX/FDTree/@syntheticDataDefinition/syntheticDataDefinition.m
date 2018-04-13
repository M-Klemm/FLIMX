classdef syntheticDataDefinition < handle
    % batchJob  A class to represent synthetic data.
    properties(GetAccess = public, SetAccess = private)
        myInfo = []; %struct with the info of the channel
        myChannels = cell(0,0);
        myDir = ''; %my working directory
        myUID = ''; %my unique id
        revision = 0;
        isDirty = false;
    end
    properties (Dependent = true)
        UID = '';
        IRFName = '';
        nrSpectralChannels = 1;
        tacRange = 12.5084; %default laser repetition rate of ~80 MHz
        nrTimeChannels = 1024;
        sizeX = 32;
        sizeY = 32;
        arrayParentSDD = '';
        arrayParamName = '';
        arrayParamNr = 1;
        arrayParamStart = 10000;
        arrayParamStep = 10000;
        arrayParamEnd = 100000;
        arrayParamVal = 1;
    end
    
    methods
        function this = syntheticDataDefinition(myDir, uid)
            %constructor for sythetic data definition
            this.myDir = myDir;
            this.myUID = uid;
            %define revision HERE
            this.revision = 9;
            %may get standard values from ini-file -HERE-
            %             IRFnames = this.FLIMXObj.irfMgr.getIRFStr(1024);
            %             this.IRFName = IRFnames{1};
            %number of spectral channels
            %if(this.isOpenVisWnd() && get(this.visHandles.checkAllChannels,'Value') == 1)
            %                 this.nrSpectralChannels = 2;
            %             else
            %                 this.nrSpectralChannels = 1;
            %             end
            this.myInfo = syntheticDataDefinition.getDefaults();
        end
        
        function setDirty(this)
            %set dirty flag
            this.isDirty = true;
        end
        
        function setUID(this,val)
            %set the name of sythetic data definition
            this.myUID = val;
            
            this.isDirty = true;
        end
        
        function set.IRFName(this,val)
            %set the name of the IRF
            this.myInfo.IRFName = val;
            this.isDirty = true;
        end
        
        function set.nrSpectralChannels(this,val)
            %set number of spectral channels
            this.myInfo.nrSpectralChannels = val;
            this.isDirty = true;
        end
        
        function set.tacRange(this,val)
            %set tac range
            this.myInfo.tacRange = val;
            this.isDirty = true;
        end
        
        function set.nrTimeChannels(this,val)
            %set number of time channels
            this.myInfo.nrTimeChannels = val;
            this.isDirty = true;
        end
        
        function set.sizeX(this,val)
            %set x size
            this.myInfo.sizeX = val;
            this.isDirty = true;
        end
        
        function set.sizeY(this,val)
            %set y size
            this.myInfo.sizeY = val;
            this.isDirty = true;
        end
        
        function set.arrayParentSDD(this,val)
            %set array parameter parrent
            this.myInfo.arrayParentSDD = val;
            this.isDirty = true;
        end
        
        function set.arrayParamName(this,val)
            %set array parameter name
            this.myInfo.arrayParamName = val;
            this.isDirty = true;
        end
        
        function set.arrayParamNr(this,val)
            %set array parameter nr
            this.myInfo.arrayParamNr = val;
            this.isDirty = true;
        end
        
        function set.arrayParamStart(this,val)
            %set array parameter start value
            this.myInfo.arrayParamStart = val;
            this.isDirty = true;
        end
        
        function set.arrayParamStep(this,val)
            %set array parameter step size
            this.myInfo.arrayParamStep = val;
            this.isDirty = true;
        end
        
        function set.arrayParamEnd(this,val)
            %set array parameter end value
            this.myInfo.arrayParamEnd = val;
            this.isDirty = true;
        end
        
        function set.arrayParamVal(this,val)
            %set my array parameter value
            this.myInfo.arrayParamVal = val;
            this.isDirty = true;
        end
        
        function [success, name] = loadFromDisk(this)
            %load sythetic data definition from disk
            success = false;
            name = '';
            try
                import = load(fullfile(this.myDir,this.myUID,'synthDataDef.mat'));
            catch
                %file not found
                return
            end
            import = import.export;
            %             if(import.revision ~= this.revision)
            %                 %version problem
            %                 import = this.updateJobVer(import);
            %             end
            %[import,dirty] = this.checkJobConsistency(import);
            if(import.revision < 8)
                %todo warning that sythetic data definition is too old
                return
            elseif(import.revision >= 8 && import.revision ~= this.revision)
                import = this.checkRevision(import);
            end
            this.setMyDataFromStruct(import);
            name = import.myUID;
            success = true;
        end
                
        function out = newChannel(this,ch)
            %create a new channel
            out = syntheticDataChannel(this);
            out.channelNr = ch;
            if(isempty(this.myChannels))%ch > this.nrSpectralChannels || isempty(this.myChannels) || isempty(this.myChannels(ch))
                this.myChannels = cell(ch,1);
            end
            this.myChannels{ch} = out;
            this.nrSpectralChannels = max(this.nrSpectralChannels,ch);
        end
        
        function setChannel(this,ch,val)
            %set struct of new channel
            this.myChannels(ch) = checkStructConsistency(val,this.getDefaultChannel);
            this.nrSpectralChannels = max(this.nrSpectralChannels,ch);
            this.isDirty = true;
        end
        
        %% modification methods
        function selfDestruct(this)
            %delete me from disk
            [status, message, messageid] = rmdir(fullfile(this.myDir,this.myUID),'s');
        end
        
        function moveChannel(this,old,new)
            %move sythetic data definition for channel old to channel new
            if(new ~= old)
                sdc = this.myChannels{old};
                sdc.channelNr = new;
                this.myChannels(new) = {sdc};
                this.myChannels(old) = cell(1,1);
                this.nrSpectralChannels = new;
                this.isDirty = true;
            end
        end
                
        function deleteChannel(this,ch)
            %remove a channel
            if(ch <= length(this.myChannels))
                this.myChannels(ch) = cell(1,1);
                this.isDirty = true;
            end
        end
        
        
        %% output methods
        function [out, mask] = nonEmptyChannelStr(this)
            %return string containing numbers of used (non-empty) channels
            str = '';
            mask = false(length(this.myChannels),1);
            for ch = 1:length(this.myChannels)
                if(~isempty(this.myChannels{ch}))
                    str = sprintf('%s%d,',str,ch);
                    mask(ch,1) = true;
                end
            end
            out = str(1:end-1);
        end
        
        function out = getChannel(this,ch)
            %return sythetic data definition for channel ch
            out = [];
            if(ch <= length(this.myChannels))
                out = this.myChannels{ch};
            end
        end
        
        function out = getCopy(this,copyDir,copyName)
            %make a copy of me with a new name
            out = syntheticDataDefinition(copyDir,copyName);
            s = this.getStructFromMyData();
            s.myUID = copyName;
            out.setMyDataFromStruct(s);
        end
        
        function saveToDisk(this)
            %save sythetic data definition to disk
            export = this.getStructFromMyData();
            dStr = fullfile(this.myDir,this.myUID);
            if(~isdir(dStr))
                [status, message, ~] = mkdir(dStr);
                if(~status)
                    error('FLIMX:FDTree:sytheticDataDefinition','Could not create sythetic data definition folder: %s\n%s',dStr,message);
                end
            end
            save(fullfile(this.myDir,this.myUID,'synthDataDef.mat'),'export');
            this.isDirty = false;
        end
        
        function simParams = checkRevision(this,oldParams)
            %update simulation parameters to current revision
            if(oldParams.revision == 8)
                simParams = oldParams;
                for ch = 1:length(simParams.myChannels)
                    if(simParams.myChannels{ch}.dataSourceType < 3)
                        %remove v-shift
                        simParams.myChannels{ch}.xVec(end-2) = [];
                    end
                end                
            end
        end
        
        function out = get.UID(this)
            %get my name
            out = this.myUID;
        end
        
        function out = get.IRFName(this)
            %get the name of the IRF
            out = this.myInfo.IRFName;
        end
        
        function out = get.nrSpectralChannels(this)
            %get number of spectral channels
            out = this.myInfo.nrSpectralChannels;
        end
        
        function out = get.tacRange(this)
            %get tac range
            out = this.myInfo.tacRange;
        end
        
        function out = get.nrTimeChannels(this)
            %get number of time channels
            out = this.myInfo.nrTimeChannels;
        end
        
        function out = get.sizeX(this)
            %get x size
            out = this.myInfo.sizeX;
        end
        
        function out = get.sizeY(this)
            %get y size
            out = this.myInfo.sizeY;
        end
        
        function out = get.arrayParentSDD(this)
            %get array parameter parrent
            out = this.myInfo.arrayParentSDD;
        end
        
        function out = get.arrayParamName(this)
            %get array parameter name
            out = this.myInfo.arrayParamName;
        end
        
        function out = get.arrayParamNr(this)
            %get array parameter nr
            out = this.myInfo.arrayParamNr;
        end
        
        function out = get.arrayParamStart(this)
            %get array parameter start value
            out = this.myInfo.arrayParamStart;
        end
        
        function out = get.arrayParamStep(this)
            %get array parameter step size
            out = this.myInfo.arrayParamStep;
        end
        
        function out = get.arrayParamEnd(this)
            %get array parameter end value
            out = this.myInfo.arrayParamEnd;
        end
        
        function out = get.arrayParamVal(this)
            %get my array parameter value
            out = this.myInfo.arrayParamVal;
        end
    end
    
    methods(Access = protected)
        function export = getStructFromMyData(this)
            %write all data into a struct (internal use only!)
            export.myUID = this.myUID;
            export.myInfo = this.myInfo;
            for ch = 1:length(this.myChannels)
                sdc = this.myChannels{ch};
                if(~isempty(sdc))
                    export.myChannels{ch} = sdc.getData();
                end
            end
            export.revision = this.revision;
        end
        
        function setMyDataFromStruct(this,import)
            %set my using a struct (internal use only: no checks are done!)
            this.myUID = import.myUID;            
            this.myInfo = import.myInfo;
            this.myChannels = cell(0,0);
            for ch = 1:length(import.myChannels)
                if(isempty(import.myChannels{ch}))
                    this.myChannels(ch) = cell(1,1);
                else
                    sdc = syntheticDataChannel(this);
                    sdc.setData(import.myChannels{ch});
                    this.myChannels{ch} = sdc;
                end
            end
        end
    end
    methods(Static)
        function out = getDefaults()
            %get default info values
            out.IRFName = '';
            out.nrSpectralChannels = 1;
            out.tacRange = 12.5084; %default laser repetition rate of ~80 MHz
            out.nrTimeChannels = 1024;
            out.sizeX = 32;
            out.sizeY = 32;
            out.arrayParentSDD = '';
            out.arrayParamName = '';
            out.arrayParamNr = 1;
            out.arrayParamStart = 10000;
            out.arrayParamStep = 10000;
            out.arrayParamEnd = 100000;
            out.arrayParamVal = 1;
        end
    end
end