classdef IRFMgrGUI < handle
    %=============================================================================================================
    %
    % @file     IRFMgrGUI.m
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
    % @brief    A class to represent the GUI for the IRF manager
    %
    properties(GetAccess = public, SetAccess = private)
        IRFMgrObj = []; %handle to IRF manager object
        visHandles = []; %structure to handles in GUI
        lastImportPath = cd;
    end
    properties (Dependent = true)
        currentIRF = '';
        currentTimePoints = [];
        currentSpectralCh = [];
        currentTacRange = [];
        currentRepRate = [];
    end
    
    methods
        function this = IRFMgrGUI(IRFMgr)
            %constructor for IRFMgrGUI
            this.IRFMgrObj = IRFMgr;
            
        end
        
        %% GUI & menu callbacks
        function menuExit_Callback(this,hObject,eventdata)
            %executes on figure close
            %close IRFMgrGUI
            if(~isempty(this.visHandles) && ishandle(this.visHandles.IRFManagerFigure))
                delete(this.visHandles.IRFManagerFigure);
            end
        end
        
        function GUI_tableIRFSel_Callback(this,hObject,eventdata)
            %
            if(~isempty(eventdata) && ~isempty(eventdata.Indices))
                set(this.visHandles.popupCurrentIRF,'Value',min(eventdata.Indices(1),length(get(this.visHandles.popupCurrentIRF,'String'))));
            end
            this.updateGUI();
        end
        
        function GUI_buttonImport_Callback(this,hObject,eventdata)
            %import a new IRF file
            [file,path] = uigetfile({'*.asc','ASCII files [SPCImage >= 3.97] (*.asc)';},'Import IRF ASCII file','MultiSelect', 'off',this.lastImportPath);
            if(~file)
                return;
            end
            this.lastImportPath = path;
            [~,name,~] = fileparts(file);
            fn = fullfile(path,file);
            try
                data = load(fn,'-ASCII');
            catch ME
                
            end
            [nTime, c] = size(data);
            %todo: check if nTime is power of 2
            if(c ~= 2)
                %show some error / warning info
                %try to use data of only one column?
            end
            overwrite = false;
            while true
                [settings, button] = settingsdlg(...
                    'Description', sprintf('Please enter some info about the IRF file to be imported.\n\nThe number of time channels is %d.',nTime),...
                    'title' , 'IRF Import',...
                    {'IRF Name';'iName'},name ,...
                    {'TAC Range';'iTAC'},data(end,1),...
                    {'Spectral Channel';'iCh'},1);
                %check user inputs
                if(~strcmpi(button, 'ok') || isempty(settings.iName))
                    %user pressed cancel or has entered rubbish -> abort
                    return
                end
                %check if we have that IRF name already, if yes ask for overwrite
                if(~isempty(this.IRFMgrObj.getIRF(nTime,settings.iName,settings.iTAC,settings.iCh)))
                    choice = questdlg(sprintf('An IRF called ''%s'' with %d time channels and spectral channel %d already exists.',settings.iName,nTime,settings.iCh),'IRF exists','Overwrite','Rename','Cancel','Rename');
                    switch choice
                        case 'Overwrite'
                            overwrite = true;
                            break
                        case 'Rename'
                            continue
                        otherwise
                            return
                    end
                else
                    break
                end
            end
            %add the new IRF to the manager
            this.IRFMgrObj.addIRF(settings.iName,settings.iCh,data,overwrite);
            this.updateGUI();
        end
        
        function GUI_buttonExport_Callback(this,hObject,eventdata)
            
        end
        
        function GUI_buttonRename_Callback(this,hObject,eventdata)
            
        end
        
        function GUI_buttonSave_Callback(this,hObject,eventdata)
            
        end
        
        function GUI_buttonDelete_Callback(this,hObject,eventdata)
            if(~isMultipleCall() && ~isempty(this.IRFMgrObj.getIRF(this.currentTimePoints,this.currentIRF,this.currentTacRange,this.currentSpectralCh)))
                choice = questdlg(sprintf('Delete IRF ''%s'' with %d time points, a repetition rate of %d MHz and spectral channel %d?',this.currentIRF,this.currentTimePoints,this.currentRepRate,this.currentSpectralCh),'Delete IRF?','Delete','Cancel','Cancel');
                switch choice
                    case 'Delete'
                        this.IRFMgrObj.deleteIRF(this.currentTimePoints,this.currentIRF,this.currentSpectralCh);
                end
            end
            this.updateGUI();
        end
        
        function GUI_buttonOK_Callback(this,hObject,eventdata)
            this.menuExit_Callback();
        end
        
        function GUI_popupTimeRes_Callback(this,hObject,eventdata)
            this.updateGUI();
        end
        
        function GUI_popupChannel_Callback(this,hObject,eventdata)
            this.updateGUI();
        end
        
        function GUI_popupCurrentIRF_Callback(this,hObject,eventdata)
            %change currently selected IRF
            try
                sp = findjobj(this.visHandles.tableIRFSel); %,'persist'
                components = sp.getComponents;
                viewport = components(1);
                curComp = viewport.getComponents;
                jtable = curComp(1);
                % jtable.setRowSelectionAllowed(0);
                % jtable.setColumnSelectionAllowed(0);
                jtable.changeSelection(hObject.Value-1,0, false, false);
            catch
            end
            this.updateGUI();
        end
                
        function GUI_popupRepRate_Callback(this,hObject,eventdata)
            this.updateGUI();
        end
        
        function GUI_checkNormalize_Callback(this,hObject,eventdata)
            this.updateGUI();
        end
        
        %% internal methods
        function createVisWnd(this)
            %make a new window for study management
            this.visHandles = IRFManagerFigure();
            set(this.visHandles.IRFManagerFigure,'CloseRequestFcn',@this.menuExit_Callback);
            %axes
            axis(this.visHandles.axesIRFView,'off');
            %set callbacks
            %tables
            set(this.visHandles.tableIRFSel,'CellSelectionCallback',@this.GUI_tableIRFSel_Callback);
            %buttons
            %set(this.visHandles.buttonClose,'Callback',@this.menuExit_Callback);
            set(this.visHandles.buttonImport,'Callback',@this.GUI_buttonImport_Callback);
            set(this.visHandles.buttonSave,'Callback',@this.GUI_buttonSave_Callback);
            set(this.visHandles.buttonDelete,'Callback',@this.GUI_buttonDelete_Callback);
            set(this.visHandles.buttonExport,'Callback',@this.GUI_buttonExport_Callback);
            set(this.visHandles.buttonRename,'Callback',@this.GUI_buttonRename_Callback);
            set(this.visHandles.buttonOK,'Callback',@this.GUI_buttonOK_Callback);
            %popups
            set(this.visHandles.popupTimeRes,'Callback',@this.GUI_popupTimeRes_Callback);
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback);
            set(this.visHandles.popupCurrentIRF,'Callback',@this.GUI_popupCurrentIRF_Callback);
            set(this.visHandles.popupRepRate,'Callback',@this.GUI_popupRepRate_Callback);
            %checkboxes
            set(this.visHandles.checkNormalize,'Callback',@this.GUI_checkNormalize_Callback);
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.IRFManagerFigure) || ~strcmp(get(this.visHandles.IRFManagerFigure,'Tag'),'IRFManagerFigure'));
        end
        
        function checkVisWnd(this)
            %check if my window is open, if not: create it
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.updateGUI();
            figure(this.visHandles.IRFManagerFigure);
        end
        
        function updateGUI(this)
            %update GUI with current data
            if(~this.isOpenVisWnd())
                return
            end
            timeRes = this.IRFMgrObj.getTimeResolutions();
            if(isempty(timeRes))
                %we seem to have not a single IRF
                set(this.visHandles.popupTimeRes,'String','-','Value',1,'Enable','off');
                set(this.visHandles.popupCurrentIRF,'String','-','Value',1,'Enable','off');
                set(this.visHandles.popupRepRate,'String','-','Value',1,'Enable','off');
                set(this.visHandles.popupChannel,'String','-','Value',1,'Enable','off');
                set(this.visHandles.editFWHM,'String','-');
                set(this.visHandles.tableIRFData,'Data',cell(2,1));
                cla(this.visHandles.axesIRFView);
                set(this.visHandles.tableIRFSel,'Data',cell(1,1));                
                return                
            end
            timeRes = num2cell(timeRes);
            set(this.visHandles.popupTimeRes,'String',timeRes,'Value',min(get(this.visHandles.popupTimeRes,'Value'),length(timeRes)),'Enable','on');
            IRFNames = this.IRFMgrObj.getIRFNames(this.currentTimePoints);
            set(this.visHandles.popupCurrentIRF,'String',IRFNames,'Value',min(get(this.visHandles.popupCurrentIRF,'Value'),length(IRFNames)),'Enable','on');
            repRates = num2cell(this.IRFMgrObj.getRepRates(this.currentTimePoints,this.currentIRF));
            set(this.visHandles.popupRepRate,'String',repRates,'Value',min(get(this.visHandles.popupRepRate,'Value'),length(repRates)),'Enable','on');
            specChans = num2cell(this.IRFMgrObj.getSpectralChNrs(this.currentTimePoints,this.currentIRF,this.currentTacRange));
            set(this.visHandles.popupChannel,'String',specChans,'Value',min(get(this.visHandles.popupChannel,'Value'),length(specChans)),'Enable','on');
            %currently selected IRF
            irf = this.IRFMgrObj.getIRF(this.currentTimePoints,this.currentIRF,this.currentTacRange,this.currentSpectralCh);
            tVec = linspace(0,this.currentTacRange,this.currentTimePoints);
            set(this.visHandles.editFWHM,'String',sprintf('%3.1f ps',1000*IRFMgrGUI.compFWHM(tVec,irf)));
            if(isempty(irf))
                set(this.visHandles.tableIRFData,'Data',cell(0,0));
                cla(this.visHandles.axesIRFView);
            else
                %fill tables
                set(this.visHandles.tableIRFData,'Data',num2cell([tVec',irf]));
                %plot current IRF
                if(get(this.visHandles.checkNormalize,'Value'))
                    irf = irf./max(irf(:));
                end
                semilogy(this.visHandles.axesIRFView,tVec,irf,'Color',[0 0 0]);
                xlim(this.visHandles.axesIRFView,[tVec(1) tVec(end)]);
            end
            xlabel(this.visHandles.axesIRFView,'Time (ns)');
            %grid(this.visHandles.axesIRFView,'on');
            set(this.visHandles.axesIRFView,'color',[1 0.95 0.9]);
            for i = 1:length(IRFNames)
                chs = this.IRFMgrObj.getSpectralChNrs(this.currentTimePoints,IRFNames{i,1},this.currentTacRange);
                tmp = '';
                for j = 1:length(chs)
                    tmp = sprintf('%s%d, ',tmp,chs(j));
                end
                tmp = tmp(1:end-2);
                IRFNames(i,2) = {tmp};
            end
            set(this.visHandles.tableIRFSel,'Data',IRFNames);
        end
        
        function out = get.currentIRF(this)
            %get name of currently selected IRF
            out = '';
            str = get(this.visHandles.popupCurrentIRF,'String');
            if(~isempty(str) && iscell(str))
                out = str{max(1,get(this.visHandles.popupCurrentIRF,'Value'))};
            elseif(ischar(str))
                out = str;
            end
        end
        
        
        function out = get.currentTimePoints(this)
            %get current number of time points
            out = '';
            str = get(this.visHandles.popupTimeRes,'String');
            if(~isempty(str) && iscell(str))
                out = str{max(1,get(this.visHandles.popupTimeRes,'Value'))};
                out = str2double(out);
            elseif(ischar(str))
                out = str;
                out = str2double(out);
            end
        end
        
        function set.currentTimePoints(this,val)
            %set current number of time points
            str = this.visHandles.popupTimeRes.String;
            timePoints = [];
            if(~isempty(str) && iscell(str))
                timePoints = cellfun(@str2double,str);
            elseif(ischar(str))
                timePoints = str2double(str);
            end
            hit = find(timePoints == val);
            if(~isempty(hit))
                this.visHandles.popupTimeRes.Value = hit;
            end
            this.updateGUI();
        end
        
        function out = get.currentSpectralCh(this)
            %get current spectral channel number
            out = '';
            str = get(this.visHandles.popupChannel,'String');
            if(~isempty(str) && iscell(str))
                out = str{get(this.visHandles.popupChannel,'Value')};
                out = str2double(out);
            elseif(ischar(str))
                out = str;
                out = str2double(out);
            end
        end
        
        function out = get.currentRepRate(this)
            %get current repetition rate
            out = [];
            str = get(this.visHandles.popupRepRate,'String');
            if(~isempty(str) && iscell(str))
                out = str{get(this.visHandles.popupRepRate,'Value')};
                out = str2double(out);
            elseif(ischar(str))
                out = str;
                out = str2double(out);
            end
        end
        
        function out = get.currentTacRange(this)
            %get current tac range
            out = this.currentRepRate;
            if(~isempty(out))
                out = 1000./out;
            end
        end
        
        
        
    end %methods
    
    methods(Static)
        function fwhm = compFWHM(t_vec,data)
            %computes the FWHM (full width (at) half maximum) for the vector data
            if(isempty(data))
                fwhm = 0;
                return
            end
            %hm = data(data > max(data(:))/2);
            hm = max(data(:))/2;
            idx = find(data > hm);
            %interpolate lower border
            t_low = compDt(data,t_vec,idx(1)-1,idx(1));
            t_high = compDt(data,t_vec,idx(end),min(idx(end)+1,length(data)));
            fwhm = t_high-t_low;
            
            function t = compDt(data,t_vec,it0,it1)
                %compute interpolated time for indices it0 and it1
                da1 = abs(data(it0) - data(it1));
                dax = abs(data(it0) - max(data(:))/2);
                dt1 = abs(t_vec(it0) - t_vec(it1));
                dtx = dax/da1*dt1;
                t = t_vec(it0) + dtx;
            end
        end
    end %methods(Static)
    
end %classdef
