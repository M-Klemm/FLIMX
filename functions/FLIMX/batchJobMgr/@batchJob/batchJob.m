classdef batchJob < handle
    % batchJob  A class to represent a batch job.
    properties
        myDir = ''; %batch jobs working directory
        myUID = ''; %batch jobs unique id
        batchJobMgr = []; %my manager
        revision = 0;
        myParams = [];
        myStudy = '';
        mySubject = '';
        myChannel = 0;
        myROI = [];       
        myRawPicture = []; %overview of the job data
        myROIPicture = [];
    end
    properties(GetAccess = public, SetAccess = private)
        
    end
    properties (Dependent = true)
        
    end

    methods
        function this = batchJob(batchJobMgr,myDir,uid)
            %constructor for batchJob
            this.myDir = myDir;
            this.myUID = uid;
            this.batchJobMgr = batchJobMgr; 
            %define revision HERE
            this.revision = 5;
        end
        
        function flag = eq(j1,j2)
            %compare two job objects 
            if(ischar(j2))
                flag = strcmp(j1.myUID,j2);
            else
                flag = strcmp(j1.myUID,j2.myUID);
            end
        end
        
        %% input methods
        function setJobData(this,params,fluoFile,chNrs)
            %put all the info into the job it needs
            this.myParams = params;
            this.myStudy = fluoFile.getStudyName();
            this.mySubject = fluoFile.getDatasetName();
            this.myChannel = chNrs;            
            this.myROI = fluoFile.ROICoordinates;       
            this.myRawPicture = fluoFile.getRawDataFlat(this.myChannel(1));
            this.saveInfoToDisk();
%             this.saveDataToDisk(fluoData);
        end
        
        function setJobParams(this,params)
            %set job parameters
            this.myParams = params;
            %this.saveInfoToDisk();
        end
        
        function [success pos] = loadInfoFromDisk(this)
            %load job from disk
            pos = 0;
            success = false;
            try
                import = load(fullfile(this.myDir,'jobInfo.mat'));
            catch
                %file not found
                return
            end
            import = import.export;            
%             if(import.revision ~= this.revision)
%                 %version problem
%                 import = this.updateJobVer(import);
%             end            
            %[import,dirty] = batchJob.checkJobConsistency(import);
            if(import.revision < 5)
                %todo warning that batch job is too old
                return
            end
            pos = import.myPos;
            this.myUID = import.myUID;
            this.myParams = import.myParams;
%             this.myFluoFileInfo = import.myFluoFileInfo;
            this.myStudy = import.myStudy;
            this.mySubject = import.mySubject;
            this.myChannel = import.myChannel;
            this.myROI = import.myROI;
            this.myRawPicture = import.myRawPicture;            
%             if(dirty)
%                 this.setDirty();
%             end
            success = true;
        end
        
        %% modification methods
        function selfDestruct(this)
            %delete me from disk
            [status, message, messageid] = rmdir(this.myDir,'s');
        end
        
        %% output methods        
        function saveInfoToDisk(this)
            %save current job data to disk
            export.myPos = this.batchJobMgr.getMyID(this);
            export.myUID = this.myUID;
            export.myParams = this.myParams;
%             export.myFluoFileInfo = this.myFluoFileInfo;
            export.myStudy = this.myStudy;
            export.mySubject = this.mySubject;
            export.myChannel = this.myChannel;
            export.myROI = this.myROI;
            export.myRawPicture = this.myRawPicture;          
            export.revision = this.revision;
            save(fullfile(this.myDir,'jobInfo.mat'),'export');
        end
        
%         function saveDataToDisk(this,data)
%             %save current job data to disk
%             save(fullfile(this.myDir,'jobData.mat'),'data');
%         end
        
        function out = getParams(this)
            %return approximation parameters
            out = this.myParams;
        end
        
        %         function out = getFluoFileInfo(this)
        %             %return fluorescence file info
        %             out = this.myFluoFileInfo;
        %         end
        
        %         function out = getFluoData(this)
        %             %return fluo data
        %             try
        %                 out = load(fullfile(this.myDir,'jobData.mat'));
        %                 out = out.data;
        %             catch
        %                 %file not found
        %                 out = [];
        %             end
        %         end
        
        function out = getStudy(this)
            %return name of study
            out = this.myStudy;
        end
        
        function out = getSubject(this)
            %return name of subject
            out = this.mySubject;
        end
        
        function out = getChannel(this)
            %return number of channels
            out = this.myChannel;
        end
        
        function out = getROI(this)
            %return coordinates of region of interest
            out = this.myROI;
        end 
                
        function [raw, roi] = getPictures(this)
            %return picture of the job
            raw = this.myRawPicture;
            co = this.myROI;
            roi = raw(co(3):co(4),co(1):co(2));
        end 
        
        function out = getUID(this)
            %return unique id of job
            out = this.myUID;
        end
            
    end %methods
    
    methods(Static)
        
        
    end
end

