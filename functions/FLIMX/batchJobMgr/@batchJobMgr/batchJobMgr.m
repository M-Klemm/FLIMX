classdef batchJobMgr < handle
    %=============================================================================================================
    %
    % @file     batchJobMgr.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  1.0
    % @date     July, 2015
    %
    % @section  LICENSE
    %
    % Copyright (C) 2015, Matthias Klemm. All rights reserved.
    %
    % Redistribution and use in source and binary forms, with or without modification, are permitted provided that
    % the following conditions are met:
    %     * Redistributions of source code must retain the above copyright notice, this list of conditions and the
    %       following disclaimer.
    %     * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
    %       the following disclaimer in the documentation and/or other materials provided with the distribution.
    %     * Neither the name of FLIMX authors nor the names of its contributors may be used
    %       to endorse or promote products derived from this software without specific prior written permission.
    %
    % THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
    % WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
    % PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
    % INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
    % PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
    % HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
    % NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    % POSSIBILITY OF SUCH DAMAGE.
    %
    %
    % @brief    A class to represent the batch job manager
    %
    properties
        myJobs = []; %list of my jobs
        myDir = []; %job manager working directory
        myGUI = []; %handle to batch job manager GUI
        FLIMXObj = []; %handle to FLIMX class
        oldInitFitParams = [];
        oldPixelFitParams = [];
        oldOptParams = [];
        oldBounds = [];        
        runningJobUID = []; %unique id of currently running job
        stopFlag = false;
    end
    properties(GetAccess = public, SetAccess = private)
        
    end
    properties (Dependent = true)
    end

    methods
        function this = batchJobMgr(flimX,myDir)
            %constructor for batchJobMgr
            this.myDir = myDir;
            if(~isdir(myDir))
                [status, message, ~] = mkdir(myDir);
                if(~status)
                    error('FLIMX:batchJobMgr:createRootFolder','Could not create batch job manager root folder: %s\n%s',myDir,message);
                end
            end
            this.FLIMXObj = flimX;
            this.myJobs = LinkedList();
            this.scanForJobs();
        end
        
        %% input methods
        function job = addJob(this,jName)
            %create a new job
            jDir = fullfile(this.myDir,jName);
            if(~isdir(jDir))
                [status, message, ~] = mkdir(jDir);
                if(~status)
                    error('FLIMX:batchJobMgr:addJob','Could not create folder for batch job: %s\n%s',jDir,message);
                end
            end
            id = this.myJobs.insertEnd(batchJob(this,jDir,jName));
            job = this.myJobs.getDataByID(id);
        end
        
        function newJob(this,jName,params,fluoFile,chNrs)
            %add a new job at the end of the joblist
            if(isempty(fluoFile))
                return
            end            
            job = this.addJob(jName); %if loaded == true jName was already used
            if(isfield(params,'folders'))
                params = rmfield(params,{'folders'});
            end
            if(isfield(params,'computation'))
                params = rmfield(params,{'computation'});
            end
            if(isempty(chNrs))
                %all available channels
                chNrs = fluoFile.getNonEmptyChannelList('');
            else
                %only selected channels - check we we have them
                chNrs = intersect(fluoFile.getNonEmptyChannelList(''),chNrs);                
            end
            if(isempty(chNrs))
                return
            end
            %determine start- and endposition, build reflection mask (may need user input)
            for ch = chNrs
                fluoFile.getReflectionMask(ch);
            end
            %check if we have a valid irf for approximation
            for ch = chNrs
                if(length(this.FLIMXObj.irfMgr.getCurIRF(ch)) ~= fluoFile.nrTimeChannels)
                    [irfStr,IRFmask] = this.FLIMXObj.irfMgr.getIRFNames(fluoFile.nrTimeChannels);
                    [settings, button] = settingsdlg(...
                        'Description', 'The currently selected IRF is not valid for parameter approximation. Please choose a valid IRF from the list below.',...
                        'title' , 'IRF Selection',...
                        {'IRF name';'IRFid'}, irfStr);
                    %check user inputs
                    if(~strcmpi(button, 'ok') || isempty(settings.IRFid))
                        %user pressed cancel or has entered rubbish -> abort
                        return
                    end
                    params.basic_fit.curIRFID = IRFmask(strcmp(settings.IRFid,irfStr));
                end
            end
            job.setJobData(params,fluoFile,chNrs);
        end
        
        function scanForJobs(this)
            %scan the disk for batch jobs
            dirs = dir(this.myDir);
            tStart = clock;
            if(length(dirs) > 10)
                hwb = waitbar(0,'Scanning for Batch Jobs');
            else
                hwb = [];
            end
            for i = 1:length(dirs)
                jName = dirs(i,1).name;
                if(dirs(i,1).isdir && ~strcmp(jName,'.') && ~strcmp(jName,'..'))
                    job = batchJob(this,fullfile(this.myDir,jName),jName);
                    %try to load the job data
                    [success, pos] = job.loadInfoFromDisk();
                    if(success)
                        this.myJobs.insertID(job,pos,false);
                    end
                end
                [~, minutes, secs] = secs2hms(etime(clock,tStart)/i*(length(dirs)-i)); %mean cputime for finished runs * cycles left
                if(ishandle(hwb))
                    waitbar(i/length(dirs),hwb,sprintf('Scanning for Batch Jobs %02.1f%% - Time left: %02.0fm %02.0fs',i/length(dirs)*100,minutes,secs));
                end
            end
            this.myJobs.updateIDs();
            if(ishandle(hwb))
                close(hwb)
            end
            %this.saveAll();
        end         
        
        %% modification methods
        function deleteJob(this,uid)
            %delete job with id from joblist
            idx = this.uid2Idx(uid);
            job = this.myJobs.getDataByPos(idx);
            if(isempty(job))
                return
            end
            job.selfDestruct();
            this.myJobs.removeID(idx);
            this.myJobs.updateIDs();
        end
        
        function deleteAllJobs(this)
            %delete all jobs joblist
            for i = this.myJobs.queueLen:-1:1
                job = this.myJobs.getDataByPos(i);
                if(~isempty(job))
                    job.selfDestruct();
                end
                this.myJobs.removeID(i);                
            end
        end
        
        function saveAllInfo(this)
            %force to write all jobs to disk
            for i = 1:this.myJobs.queueLen
                job = this.myJobs.getDataByPos(i);
                if(~isempty(job))
                    job.saveInfoToDisk();
                end
            end
        end
                
        function setJobID(this,uid,newId)
            %change position of a job in the joblist to newID
            idx = this.uid2Idx(uid);
            job = this.myJobs.getDataByPos(idx);
            if(isempty(job) || newId == idx)
                return
            end
            this.myJobs.removeID(idx);
            this.myJobs.updateIDs();
            this.myJobs.insertID(job,newId,false);
            this.myJobs.updateIDs();
            this.saveAllInfo();
        end
        
        function setGUIHandle(this,hGUI)
            %set handle to batch job manager GUI
            this.myGUI = hGUI;
        end
        
        function setStop(this,val)
            %set the stop flag
            this.stopFlag = logical(val);
        end
        
        %% output methods
        function out = getNrJobs(this)
            %return the number of jobs in list
            out = this.myJobs.queueLen;
        end
        
        function id = getMyID(this,job)
            %return the current id (running number) of the job
            id = this.myJobs.getIDByData(job);
        end
        
        function job = getJob(this,idx)
            %return job with id
            job = this.myJobs.getDataByPos(this.uid2Idx(idx));
        end
                
        function info = getAllJobsInfo(this)
            %return 'overview' info about all jobs in joblist
            info = cell(this.myJobs.queueLen,4);
            for i = 1:this.myJobs.queueLen
                job = this.myJobs.getDataByPos(i);
                info(i,:) = {job.getUID(),job.getStudy(),job.getSubject(),num2str(job.getChannel())};
            end
        end
        
        function out = getJobUID(this,idx)
            %get unique id of job
            out = cell(0,0);
            for i = 1:length(idx)
                job = this.getJob(idx(i));
                if(~isempty(job))
                    out{end+1} = job.getUID();
                end
            end
        end
        
        function out = getRunningJobUID(this)
            %return the unique id of the currently running job
            out = this.runningJobUID;
        end
        
        function out = getJobROI(this,uid)
            %get region of interest from job
            out = [];
            job = this.getJob(uid);
            if(~isempty(job))
                out = job.getROI();
            end
        end
        
        function [raw, roi] = getJobPictures(this,uid)
            %get picture of job id
            job = this.getJob(uid);
            if(isempty(job))
                raw = []; roi = [];
            else
                [raw, roi] = job.getPictures();
            end
        end
        
        function idx = uid2Idx(this,uid)
            %convert a jobs uid to its position in the joblist
            idx = [];
            if(iscell(uid))
                uid = char(uid{1,1});
            end
            if(ischar(uid))
                idx = this.myJobs.getPosByData(uid);
            elseif(isnumeric(uid))
                if(uid <= this.myJobs.queueLen)
                    idx = uid;
                end
            end        
        end
        
        %% execution methods
        function success = loadJob(this,uid)
            %load job with id in fit object
            success = 0;
            if(isempty(uid))
                %use first job
                job = this.myJobs.getDataByPos(1);
            else
                job = this.getJob(uid);
            end
            if(isempty(job))
                return
            end
            params = job.getParams();
            %delete old fit results
            this.FLIMXObj.fdt.removeSubjectResult(job.getStudy(),job.getSubject())
            %now load new subject and batch job parameters
            if(this.FLIMXObj.setCurrentSubject(job.getStudy(),FDTree.defaultConditionName(),job.getSubject()))
                this.FLIMXObj.curSubject.loadParameters('batchJob',params);
                this.FLIMXObj.FLIMFitGUI.currentChannel = job.myChannel(1);
                this.FLIMXObj.FLIMFitGUI.setupGUI();
                this.FLIMXObj.FLIMFitGUI.updateGUI(true);
                if(length(job.myChannel) == 1 || (isfield(params,'volatile') && isfield(params.volatile,'globalFitMask') && any(params.volatile.globalFitMask)))
                    success = 1;
                else
                    success = length(job.myChannel);
                end
                %build ROI for whole dataset before approximation
                for ch = 1:length(job.myChannel)                    
                    this.FLIMXObj.curSubject.getROIData(job.myChannel(ch),[],[]);
                end
            end            
        end
        
        function runSelectedJobs(this,jobPos,deleteFlag)
            %run jobs at position jobPos in queue
            this.stopFlag = false;
            jobs = this.getJobUID(jobPos);
            tStart = clock;
            this.updateProgress(0.001,sprintf('0/%d (0.0%%) done - Time left: estimating...',length(jobs)));                
            for i = 1:length(jobs)
                if(~isempty(jobs{i}))
                    this.startJob(jobs{i});
                    if(this.stopFlag)
                        this.setStop(false);
                        break
                    end
                    if(deleteFlag)
                        this.deleteJob(jobs{i});
                    end
                end
                timeLeft = etime(clock,tStart)/i*(length(jobs)-i);
                [hours, minutes, secs] = secs2hms(timeLeft);
                this.updateProgress(i/length(jobs),sprintf('%d/%d (%02.1f%%) done - Time left: %02.0fh %02.0fmin %02.0fsec (%s)',i,length(jobs),i/length(jobs)*100,hours,minutes,secs,datestr(addtodate(now,round(timeLeft),'second'),'dd.mm.yyyy HH:MM:SS')));
                if(this.stopFlag)
                    this.setStop(false);
                    break
                end
            end
        end
        
        function runAllJobs(this,deleteFlag)
            %run all jobs in queue
            this.runSelectedJobs(1:this.getNrJobs(),deleteFlag);
        end
        
        function startJob(this,uid)
            %run job with id in fit object
            this.runningJobUID = uid;            
            flag = this.loadJob(uid);
            if(this.stopFlag)
                return
            end
            if(flag == 1)
                %fit specfic channel or make global fit
                this.updateGUI();                
                this.FLIMXObj.FLIMFitGUI.menuFitChannel_Callback(); %todo: don't use GUI callback
            elseif(flag > 1)
                %fit all channels
                this.updateGUI();                
                this.FLIMXObj.FLIMFitGUI.menuFitAll_Callback(); %todo: don't use GUI callback
            end
            this.runningJobUID = [];
        end
            
        function updateProgress(this,prog,text)
            %either update progress bar of GUI or plot to command line
            if(~isempty(this.myGUI) && ~isempty(this.myGUI.visHandles) && ~isempty(this.myGUI.visHandles.batchJobMgrFigure))
                this.myGUI.updateProgressbar(prog,text);
            end
        end
        
        function updateGUI(this)
            %update GUI
            if(~isempty(this.myGUI))
                this.myGUI.updateGUI();
            end
        end
    end %methods
    
    methods(Static)
        
        
    end
end %classdef
