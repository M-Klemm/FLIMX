classdef batchJobMgrGUI < handle
    %=============================================================================================================
    %
    % @file     batchJobMgrGUI.m
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
    % @brief    A class to represent the GUI for the batch job manager
    %
    properties(GetAccess = public, SetAccess = private)
        FLIMXObj = []; %handle to FLIMX object
        visHandles = []; %structure to handles in GUI
        mySelJobs = 1; %ids of selected jobs
        axesRawMgr = [];
        axesROIMgr = [];
        defaultStrRunSelected = '';
        defaultStrRunAll = '';
        defaultStrStop = '';
    end
    properties (Dependent = true)
        batchJobMgr %handle of the job manager
    end

    methods
        function this = batchJobMgrGUI(flimX)
            %constructor for batchJobMgrGUI
            this.FLIMXObj = flimX;
            this.batchJobMgr.setGUIHandle(this);
        end
        
        %% GUI & menu callbacks
        function menuExit_Callback(this,hObject,eventdata)
            %executes on figure close
            this.GUI_buttonStop_Callback(this.visHandles.buttonStop,[]);
            %close batchJobMgr
            if(~isempty(this.visHandles) && ishandle(this.visHandles.batchJobMgrFigure))
                delete(this.visHandles.batchJobMgrFigure);
            end
        end
        
        function GUI_tableJobsSel_Callback(this,hObject,eventdata)
            %save the ids of the selected job(s)
            if(~isempty(eventdata.Indices))
                this.mySelJobs = eventdata.Indices(:,1);
                this.drawImages();
            end
        end
        
        function addCurJob(this)
            %add (sdt-) file to job list
            ch = get(this.visHandles.popupFileFolderChannels,'Value') - 1;
            if(ch == 0)
                %all channels
                this.FLIMXObj.FLIMFitGUI.menuBatchAll_Callback();
            else
                %specific channel
                this.FLIMXObj.FLIMFitGUI.menuBatchCurrent_Callback([],true);
            end
            this.updateGUI();
        end
        
        function GUI_buttonMove_Callback(this,hObject,eventdata)
            %move a job  up or down in job list
            tag = get(hObject,'Tag');
            if(length(tag) < 7 || isempty(this.mySelJobs))
                return
            end
            tag = tag(7:end);
            oldPos = this.mySelJobs(1);
            switch tag
                case 'Up'
                    newPos = max(1,oldPos-1);
                case 'Down'
                    newPos = min(this.batchJobMgr.getNrJobs(),oldPos+1);
                case 'Top'
                    newPos = 1;
                case 'Bottom'
                    newPos = this.batchJobMgr.getNrJobs();
            end
            this.batchJobMgr.setJobID(this.batchJobMgr.getJobUID(oldPos),newPos);
            this.mySelJobs = newPos;
            this.updateGUI();
        end
        
        function GUI_buttonRemove_Callback(this,hObject,eventdata)
            %delete job(s) from list
            jobs = this.batchJobMgr.getJobUID(this.mySelJobs);
            tStart = clock;
            allFlag = false;
            for i = 1:length(jobs)
                if(~isempty(jobs{i}))
                    if(~allFlag)
                        choice = questdlg(sprintf('Delete batch job ''%s''?',jobs{i}),...
                            'Delete Batch Job','Yes','All','Abort','Abort');
                        % Handle response
                        switch choice
                            case 'All'
                                allFlag = true;
                            case 'Abort'
                                return
                        end
                    end
                    this.batchJobMgr.deleteJob(jobs{i});
                end
                [hours, minutes, secs] = secs2hms(etime(clock,tStart)/i*(length(jobs)-i));
                this.updateProgressbar(i/length(jobs),sprintf('%d/%d (%02.1f%%) done - Time left: %02.0fh %02.0fmin %02.0fsec',i,length(jobs),i/length(jobs)*100,hours,minutes,secs));
            end
            this.updateGUI();
            this.updateProgressbar(0,'');
        end
        
        function GUI_buttonRemoveAll_Callback(this,hObject,eventdata)
            %delete all jobs
            choice = questdlg('Delete all batch jobs?',...
                'Delete All Batch Jobs','Yes','No','No');
            % Handle response
            switch choice
                case 'No'
                    return
            end
            this.batchJobMgr.deleteAllJobs();
            this.mySelJobs = 1;
            this.updateGUI();
        end
        
        function GUI_buttonLoadJob_Callback(this,hObject,eventdata)
            %load selected job(s)
            if(isempty(this.mySelJobs(1)))
                return
            end
            job = this.batchJobMgr.getJobUID(this.mySelJobs(1));
            if(~isempty(job))
                this.batchJobMgr.loadJob(job{1,1});
            end
            %this.FLIMXObj.FLIMFitGUI.setSdtLoaded(false);
            this.FLIMXObj.FLIMFitGUI.setupGUI();
            this.updateGUI();
        end
        
        function GUI_buttonRunSelected_Callback(this,hObject,eventdata)
            %run selected job(s)
            if(isempty(this.mySelJobs))
                return
            end
            try
                hObject.String = sprintf('<html><img src="file:/%s"/> Running</html>',FLIMX.getAnimationPath());
                drawnow;
            end
            this.enDisableGUICtrls('Off');
            this.batchJobMgr.runSelectedJobs(this.mySelJobs,true);
            this.updateGUI();
            this.updateProgressbar(0,'');
            hObject.String = this.defaultStrRunSelected;
            this.visHandles.buttonStop.String = this.defaultStrStop;
            this.enDisableGUICtrls('On');
        end
        
        function GUI_buttonRunAll_Callback(this,hObject,eventdata)
            %run all jobs on list
            nrJobs = this.batchJobMgr.getNrJobs();
            if(nrJobs == 0)
                return
            end
            try
                hObject.String = sprintf('<html><img src="file:/%s"/> Running</html>',FLIMX.getAnimationPath());
                drawnow;
            end
            this.enDisableGUICtrls('Off');
            this.batchJobMgr.runAllJobs(true);
            this.updateGUI();
            this.updateProgressbar(0,'');
            hObject.String = this.defaultStrRunAll;
            this.visHandles.buttonStop.String = this.defaultStrStop;  
            this.enDisableGUICtrls('On');
        end
        
        function GUI_buttonStop_Callback(this,hObject,eventdata)
            %stop after current operation
            try
                hObject.String = sprintf('<html><img src="file:/%s"/> Stop</html>',FLIMX.getAnimationPath());
                drawnow;
            end
            this.batchJobMgr.setStop(true);
            this.updateProgressbar(-1,'');
            this.FLIMXObj.FLIMFitGUI.GUI_buttonStop_Callback([],[]);
        end
        
        %% internal methods
        function createVisWnd(this)
            %make a new window for study management
            this.visHandles = batchJobMgrFigure();
            set(this.visHandles.batchJobMgrFigure,'CloseRequestFcn',@this.menuExit_Callback);
            %axes
            set(this.visHandles.axesProgress,'XLim',[0 100],...
                'YLim',[0 1],...
                'Box','on', ...
                'FontSize', get(0,'FactoryAxesFontSize'),...
                'XTickMode','manual',...
                'YTickMode','manual',...
                'XTick',[],...
                'YTick',[],...
                'XTickLabelMode','manual',...
                'XTickLabel',[],...
                'YTickLabelMode','manual',...
                'YTickLabel',[]);
            xpatch = [0 0 0 0];
            ypatch = [0 0 1 1];
            this.visHandles.patchWait = patch(xpatch,ypatch,'r','EdgeColor','r','Parent',this.visHandles.axesProgress);%,'EraseMode','normal'
            this.visHandles.textWait = text(1,0,'','Parent',this.visHandles.axesProgress);
            %axis(this.visHandles.axesProgress,'off');
            axis(this.visHandles.axesROI,'off');
            axis(this.visHandles.axesRaw,'off');
            %set callbacks
            set(this.visHandles.buttonRunSelected,'Callback',@this.GUI_buttonRunSelected_Callback);
            set(this.visHandles.buttonRunAll,'Callback',@this.GUI_buttonRunAll_Callback);
            set(this.visHandles.buttonStop,'Callback',@this.GUI_buttonStop_Callback);
            %table
            set(this.visHandles.tableJobs,'CellSelectionCallback',@this.GUI_tableJobsSel_Callback);
            set(this.visHandles.buttonUp,'String',char(173),'Callback',@this.GUI_buttonMove_Callback);
            set(this.visHandles.buttonDown,'String',char(175),'Callback',@this.GUI_buttonMove_Callback);
            set(this.visHandles.buttonTop,'String',char(221),'Callback',@this.GUI_buttonMove_Callback);
            set(this.visHandles.buttonBottom,'String',char(223),'Callback',@this.GUI_buttonMove_Callback);
            set(this.visHandles.buttonLoadJob,'Callback',@this.GUI_buttonLoadJob_Callback);
            set(this.visHandles.buttonRemove,'Callback',@this.GUI_buttonRemove_Callback);
            set(this.visHandles.buttonRemoveAll,'Callback',@this.GUI_buttonRemoveAll_Callback);
            %axes
            cm = this.FLIMXObj.FLIMFitGUI.dynVisParams.cmIntensity;
            if(isempty(cm))
                cm = gray(256);
            end
            this.axesRawMgr = axesWithROI(this.visHandles.axesRaw,this.visHandles.axesCbRaw,this.visHandles.textCbRawBottom,this.visHandles.textCbRawTop,[],cm);
            this.axesRawMgr.setColorMapPercentiles(this.FLIMXObj.FLIMFitGUI.generalParams.cmIntensityPercentileLB,this.FLIMXObj.FLIMFitGUI.generalParams.cmIntensityPercentileUB);
            this.axesRawMgr.setROILineColor('r');
            this.axesROIMgr = axesWithROI(this.visHandles.axesROI,this.visHandles.axesCbROI,this.visHandles.textCbROIBottom,this.visHandles.textCbROITop,[],cm);
            this.axesROIMgr.setColorMapPercentiles(this.FLIMXObj.FLIMFitGUI.generalParams.cmIntensityPercentileLB,this.FLIMXObj.FLIMFitGUI.generalParams.cmIntensityPercentileUB);
            this.axesROIMgr.setROILineColor('r');
            %save default button strings
            this.defaultStrRunSelected = this.visHandles.buttonRunSelected.String;
            this.defaultStrRunAll = this.visHandles.buttonRunAll.String;
            this.defaultStrStop = this.visHandles.buttonStop.String;
        end
        
        function checkVisWnd(this)
            %check if my window is open, if not: create it
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.updateGUI();
            figure(this.visHandles.batchJobMgrFigure);
        end
        
        function updateGUI(this)
            %update GUI with current data
            if(~this.isOpenVisWnd())
                return
            end
            %tables
            info = this.batchJobMgr.getAllJobsInfo();
            set(this.visHandles.tableJobs,'Data',info);
            runningJobUID = this.batchJobMgr.getRunningJobUID();
            if(isempty(runningJobUID))
                set(this.visHandles.tableCurrentJob,'Data',[]);
            else
                set(this.visHandles.tableCurrentJob,'Data',info(strcmp(runningJobUID,info(:,1)),:));
            end
            %plots
            this.drawImages();
        end
        
        function drawImages(this)
            %draw raw and ROI image
            if(~isempty(this.mySelJobs))
                [rawPic, roiPic] = this.batchJobMgr.getJobPictures(this.mySelJobs(1));
                roi = this.batchJobMgr.getJobROI(this.mySelJobs(1));
            else
                rawPic = []; roiPic = [];
            end
            if(isempty(rawPic))
                cla(this.visHandles.axesROI);
                cla(this.visHandles.axesRaw);
                set(this.visHandles.textCbROITop,'String','');
                set(this.visHandles.textCbROIBottom,'String','');
                set(this.visHandles.textCbRawTop,'String','');
                set(this.visHandles.textCbRawBottom,'String','');
                axis(this.visHandles.axesRaw,'off');
                axis(this.visHandles.axesROI,'off');
            else
                axis(this.visHandles.axesRaw,'on');
                axis(this.visHandles.axesROI,'on');
                this.axesRawMgr.setReverseYDirFlag(this.FLIMXObj.paramMgr.generalParams.reverseYDir);
                this.axesROIMgr.setReverseYDirFlag(this.FLIMXObj.paramMgr.generalParams.reverseYDir);
                %raw
                this.axesRawMgr.setColorMapPercentiles(this.FLIMXObj.paramMgr.generalParams.cmIntensityPercentileLB,this.FLIMXObj.paramMgr.generalParams.cmIntensityPercentileUB);
                this.axesRawMgr.setMainData(rawPic);
                this.axesRawMgr.drawROIBox(roi);
                %roi
                this.axesROIMgr.setColorMapPercentiles(this.FLIMXObj.paramMgr.generalParams.cmIntensityPercentileLB,this.FLIMXObj.paramMgr.generalParams.cmIntensityPercentileUB);
                this.axesROIMgr.setMainData(roiPic);
            end
            %             this.makeColorbars();
        end
        
        function makeColorbars(this)
            %draw colorbar
            cm = this.FLIMXObj.FLIMFitGUI.dynVisParams.cmIntensity;
            temp(:,1,:) = cm;
            %axes(handles.axesCb);
            image(temp,'Parent',this.visHandles.axesCbRaw);
            image(temp,'Parent',this.visHandles.axesCbROI);
            ytick = (0:0.25:1).*size(this.FLIMXObj.FLIMFitGUI.dynVisParams.cmIntensity,1);
            ytick(1) = 1;
            set(this.visHandles.axesCbRaw,'YDir','normal','YTick',ytick,'YTickLabel','','YAxisLocation','right','XTick',[],'XTickLabel','');
            ylim(this.visHandles.axesCbRaw,[1 size(this.FLIMXObj.FLIMFitGUI.dynVisParams.cmIntensity,1)]);
            set(this.visHandles.axesCbROI,'YDir','normal','YTick',ytick,'YTickLabel','','YAxisLocation','right','XTick',[],'XTickLabel','');
            ylim(this.visHandles.axesCbROI,[1 size(this.FLIMXObj.FLIMFitGUI.dynVisParams.cmIntensity,1)]);
        end
                
        function out = get.batchJobMgr(this)
            out = this.FLIMXObj.batchJobMgr;
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.batchJobMgrFigure) || ~strcmp(get(this.visHandles.batchJobMgrFigure,'Tag'),'batchJobMgrFigure'));
        end
        
        function updateProgressbar(this,x,text)
            %update progress bar; input: progress x: 0..1, text on progressbar
            if(~this.isOpenVisWnd())
                return
            end
            if(x < 0)
                %stop button pressed
                text = get(this.visHandles.textWait,'String');
                newStr = '...Stopping...';
                newLen = length(newStr);
                if(length(text) < newLen || ~strncmp(text(end-newLen+1:end),newStr,newLen))
                    text = [text newStr];
                    set(this.visHandles.textWait,'String',text);
                end
            else
                x = max(0,min(100*x,100));
                xpatch = [0 x x 0];
                set(this.visHandles.patchWait,'XData',xpatch,'Parent',this.visHandles.axesProgress)
                yl = ylim(this.visHandles.axesProgress);
                set(this.visHandles.textWait,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.axesProgress);
            end
            drawnow;
        end
        
        function enDisableGUICtrls(this,flag)
            %enables or disables all GUI controls except for the stop button
            if(~strcmpi(flag,'Off'))
                flag = 'On';
            end                
            this.visHandles.buttonRunSelected.Enable = flag;
            this.visHandles.buttonRunAll.Enable = flag;
            this.visHandles.buttonUp.Enable = flag;
            this.visHandles.buttonDown.Enable = flag;
            this.visHandles.buttonTop.Enable = flag;
            this.visHandles.buttonBottom.Enable = flag;
            this.visHandles.buttonLoadJob.Enable = flag;
            this.visHandles.buttonRemove.Enable = flag;
            this.visHandles.buttonRemoveAll.Enable = flag;            
        end
        
    end %methods
    
    methods(Static)
        
        
    end
end %classdef
