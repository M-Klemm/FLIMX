classdef syntheticDataChannel < handle
    % batchJob  A class to represent synthetic data channel.
    properties(GetAccess = protected, SetAccess = protected)
        mySDD = ''; %my parent: a synthetic data definition
        myData = []; %struct with the data of the channel
        
    end
    properties (Dependent = true)
        %my own proterties
        nrExponentials = 3;
        nrPhotons = 50000;
        xVec = [];
        tciVec = [];
        shift = [];
        offset = 0;
        fixedQ = 0;
        channelNr = 1; %channel id
        rawData = [];
        modelData = [];
        dataSourceType = 1; %1: user defined parameters, 2: result parameters, 3: data
        dataSourceDatasetName = '';
        dataSourcePos = [];        
        %of parent sdd
        UID = ''; %my unique id
        IRFName = '';
        nrSpectralChannels = 1;
        tacRange = 12.5084; %default laser repetition rate of ~80 MHz
        nrTimeChannels = 1024;
        sizeX = 32;
        sizeY = 32;
        arrayParentSDD = '';
        arrayParamName = '';
        arrayParamNr = '';
        arrayParamStart = 1;
        arrayParamStep = 1;
        arrayParamEnd = 10;
        arrayParamVal = 1;
    end

    methods
        function this = syntheticDataChannel(sdd)
            %constructor for sythetic data channel
            this.mySDD = sdd;
            this.myData = syntheticDataChannel.getDefaults();
        end
        
        function setDirty(this)
            %set dirty flag
            this.mySDD.setDirty();            
        end
        
        function setData(this,data)
            %set the data of a channel
            this.myData = checkStructConsistency(data,syntheticDataChannel.getDefaults());
%             this.setDirty();
        end
        
        function out = getData(this)
            %get the data of a channel
            out = this.myData;
        end
        
        %%dependent properties
        %get
        %local
        function out = get.nrExponentials(this)
            out = this.myData.nrExponentials;
        end
        
        function out = get.nrPhotons(this)
            out = this.myData.nrPhotons;
        end
        
        function out = get.xVec(this)
            out = this.myData.xVec;
        end
        
        function out = get.tciVec(this)
            out = this.myData.tciVec;
        end
        
        function out = get.shift(this)
            if(~isempty(this.myData.xVec))
                out = this.myData.xVec(end-1);
            else
                out = [];
            end
        end
        
        function out = get.offset(this)
            out = this.myData.offset;
        end
        
        function out = get.fixedQ(this)
            out = this.myData.fixedQ;
        end
        
        function out = get.channelNr(this)
            out = this.myData.channelNr;
        end
        
        function out = get.rawData(this)
            out = this.myData.rawData;
        end
        
        function out = get.modelData(this)
            out = this.myData.modelData;
        end
        
        function out = get.dataSourceType(this)
            out = this.myData.dataSourceType;
        end
        
        function out = get.dataSourceDatasetName(this)
            out = this.myData.dataSourceDatasetName;
        end
        
        function out = get.dataSourcePos(this)
            out = this.myData.dataSourcePos;
        end
                
        %remote
        function out = get.UID(this)
            out = this.mySDD.UID;
        end
        
        function out = get.IRFName(this)
            out = this.mySDD.IRFName;
        end
        
        function out = get.nrSpectralChannels(this)
            out = this.mySDD.nrSpectralChannels;
        end
        
        function out = get.tacRange(this)
            out = this.mySDD.tacRange;
        end
        
        function out = get.nrTimeChannels(this)
            out = this.mySDD.nrTimeChannels;
        end
        
        function out = get.sizeX(this)
            out = this.mySDD.sizeX;
        end
        
        function out = get.sizeY(this)
            out = this.mySDD.sizeY;
        end        
        
        function out = get.arrayParentSDD(this)
            out = this.mySDD.arrayParentSDD;
        end
        
        function out = get.arrayParamName(this)
            out = this.mySDD.arrayParamName;
        end
        
        function out = get.arrayParamNr(this)
            out = this.mySDD.arrayParamNr;
        end
        
        function out = get.arrayParamStart(this)
            out = this.mySDD.arrayParamStart;
        end
        
        function out = get.arrayParamStep(this)
            out = this.mySDD.arrayParamStep;
        end
        
        function out = get.arrayParamEnd(this)
            out = this.mySDD.arrayParamEnd;
        end        
        
        function out = get.arrayParamVal(this)
            out = this.mySDD.arrayParamVal;
        end
        %set
        %local
        function set.nrExponentials(this,val)
            this.myData.nrExponentials = val;
            this.myData.tciVec = ones(1,val);
            this.myData.xVec = [];
            this.myData.rawData = [];
            this.myData.modelData = [];
            this.setDirty();
        end
        
        function set.nrPhotons(this,val)
            this.myData.nrPhotons = val;            
            this.myData.rawData = [];
            this.myData.modelData = [];
            this.setDirty();
        end
        
        function set.xVec(this,val)
            this.myData.xVec = val;
            this.setDirty();
        end
        
        function set.tciVec(this,val)
            this.myData.tciVec = val;
            this.setDirty();
        end
        
        function set.shift(this,val)
            if(~isempty(this.myData.xVec))
                this.myData.xVec(end-1) = val;
            end
            this.setDirty();
        end
        
        function set.offset(this,val)
            this.myData.offset = val;
            if(~isempty(this.myData.xVec))
                this.myData.xVec(end) = val;
            end
            this.setDirty();
        end
        
        function set.fixedQ(this,val)
            this.myData.fixedQ = val;
            this.setDirty();
        end
        
        function set.channelNr(this,val)
            this.myData.channelNr = val;
            this.setDirty();
        end
        
        function set.rawData(this,val)
            this.myData.rawData = val;
            this.setDirty();
        end
        
        function set.modelData(this,val)
            this.myData.modelData = val;
            this.setDirty();
        end
        
        function set.dataSourceType(this,val)
            this.myData.dataSourceType = val;
            this.setDirty();
        end
        
        function set.dataSourceDatasetName(this,val)
            this.myData.dataSourceDatasetName = val;
            this.setDirty();
        end
        
        function set.dataSourcePos(this,val)
            this.myData.dataSourcePos = val;
            this.setDirty();
        end       
        
        %remote
        function set.UID(this,val)
            this.mySDD.setUID(val);
        end
        
        function set.IRFName(this,val)
            this.mySDD.IRFName = val;
        end
        
        function set.nrSpectralChannels(this,val)
            this.mySDD.nrSpectralChannels = val;
        end
        
        function set.tacRange(this,val)
            this.mySDD.tacRange = val;
        end
        
        function set.nrTimeChannels(this,val)
            this.mySDD.nrTimeChannels = val;
        end
        
        function set.sizeX(this,val)
            this.mySDD.sizeX = val;
        end
        
        function set.sizeY(this,val)
            this.mySDD.sizeY = val;
        end
        
        function set.arrayParentSDD(this,val)
            this.mySDD.arrayParentSDD = val;
        end
        
        function set.arrayParamName(this,val)
            this.mySDD.arrayParamName = val;
        end        
        
        function set.arrayParamNr(this,val)
            this.mySDD.arrayParamNr = val;
        end
        
        function set.arrayParamStart(this,val)
            this.mySDD.arrayParamStart = val;
        end
        
        function set.arrayParamStep(this,val)
            this.mySDD.arrayParamStep = val;
        end
        
        function set.arrayParamEnd(this,val)
            this.mySDD.arrayParamEnd = val;
        end        
        
        function set.arrayParamVal(this,val)
            this.mySDD.arrayParamVal = val;
        end
    end
    
    methods(Static)
        function out = getDefaults()
            %get structure with standard simulation parameters for channel 1          
            nExp = 3;
            xVec = zeros(3*nExp+2,1);
            %Amplitudes
            xVec(1) = 0.8;
            xVec(2) = 0.15;
            xVec(3) = 0.05;
            %Taus
            xVec(4) = 100;
            xVec(5) = 500;
            xVec(6) = 2500;
            %tcs
            xVec(7) = 0;
            xVec(8) = 0;
            xVec(9) = 0;
            %xVec(10) = 1;   %vShift;
            xVec(10) = 0;   %hShift;
            xVec(11) = 0.5; %offset            
            out.nrExponentials = nExp;
            out.nrPhotons = 50000;
            out.xVec = xVec;
            out.tciVec = ones(nExp,1);
            out.offset = xVec(end);
            out.fixedQ = 0;            
            out.channelNr = 1;              %channel id
            %simulation data for preview plot
            out.rawData = [];
            out.modelData = [];
            out.dataSourceType = 1; %1: user defined parameters, 2: result parameters, 3: data
            out.dataSourceDatasetName = '';
            out.dataSourcePos = [];
        end
    end
end