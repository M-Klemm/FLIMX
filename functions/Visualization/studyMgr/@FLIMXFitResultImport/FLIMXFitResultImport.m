classdef FLIMXFitResultImport < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(GetAccess = public, SetAccess = private)
        FLIMXObj = [];
        visHandles = [];
        allFiles = struct;
        % read
        folderpath = '';
        maxCh = [];
        curRow = '';
        curCol = '';
        % Roi
        axesMgr = [];
        measurementObj = [];
        buttonDown = false; %flags if mouse button is pressed
        finalROIVec = [];
        isDirty = false(1,5); %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
    end
    
    properties (Dependent = true)
        roiMode = 1;
        selectedCh = 1;
        currentROIVec = [];
        editFieldROIVec = [];
        myMeasurement = [];
    end
    
    methods
        %% dependent properties
        
        function out = get.myMeasurement(this)
            %get measurement or subject object
            out = this.measurementObj;
            if(isempty(out))
                out = this.FLIMXObj.curSubject.myMeasurement;
            end
        end
        function out = get.selectedCh(this)
            %get current selected channel
            if(~this.isOpenVisWnd())
                return
            end
            out = get(this.visHandles.popupChannel,'Value');
        end
        
        function set.selectedCh(this,val)
            if(~this.isOpenVisWnd())% || ~ischar(val))
                return
            end
            val(val>this.maxCh)=this.maxCh;
            set(this.visHandles.popupChannel,'Value',val);
            %             transfer = [{this.allFiles.name}',{this.allFiles.ext}',{this.allFiles.channel}',{this.allFiles.import}'];
            %             transfer = transfer(cell2mat(transfer(:,3))== this.selectedCh,:);
            %             set(this.visHandles.tableFiles,'Data',transfer);
            this.curRow = 1;
            this.updateGUI();
        end
        
        function out = get.roiMode(this)
            %return number of selected roi mode (1: whole dataset, 2: auto, 3: custom)
            if(get(this.visHandles.radioAuto,'Value'))
                out = 2;
            elseif(get(this.visHandles.radioCustom,'Value'))
                out = 3;
            else
                out = 1;
            end
        end
        
        function set.roiMode(this,val)
            %set number of selected roi mode (1: whole dataset, 2: auto, 3: custom)
            switch val
                case 2
                    set(this.visHandles.radioDefault,'Value',0);
                    set(this.visHandles.radioAuto,'Value',1);
                    set(this.visHandles.radioCustom,'Value',0);
                    flag = 'off';
                case 3
                    set(this.visHandles.radioDefault,'Value',0);
                    set(this.visHandles.radioAuto,'Value',0);
                    set(this.visHandles.radioCustom,'Value',1);
                    flag = 'on';
                otherwise
                    set(this.visHandles.radioDefault,'Value',1);
                    set(this.visHandles.radioAuto,'Value',0);
                    set(this.visHandles.radioCustom,'Value',0);
                    flag = 'off';
            end
            set(this.visHandles.textXL,'Enable',flag);
            set(this.visHandles.textXH,'Enable',flag);
            set(this.visHandles.textYL,'Enable',flag);
            set(this.visHandles.textYH,'Enable',flag);
        end
        
        function out = get.editFieldROIVec(this)
            %make roi vector from
            x = this.myMeasurement.getRawXSz();
            y = this.myMeasurement.getRawYSz();
            cXl = max(1,str2double(get(this.visHandles.textXL,'String')));
            cXu = min(x,str2double(get(this.visHandles.textXH,'String')));
            cXl = max(1,min(cXl,cXu-1));
            cXu = min(x,max(cXu,cXl+1));
            cYl = max(1,str2double(get(this.visHandles.textYL,'String')));
            cYu = min(y,str2double(get(this.visHandles.textYH,'String')));
            cYl = max(1,min(cYl,cYu-1));
            cYu = min(y,max(cYu,cYl+1));
            out = [cXl, cXu, cYl, cYu];
            %             out = [str2double(get(this.visHandles.textXL,'String')) str2double(get(this.visHandles.textXH,'String')), ...
            %             str2double(get(this.visHandles.textYL,'String')), str2double(get(this.visHandles.textYH,'String'))];
        end
        
        function set.editFieldROIVec(this,val)
            %set roi points in GUI from roi vec (apply limits)
            if(length(val) == 4)
                set(this.visHandles.textXL,'String',max(1,val(1)))
                set(this.visHandles.textXH,'String',min(this.myMeasurement.getRawXSz(),val(2)));
                set(this.visHandles.textYL,'String', max(1,val(3)))
                set(this.visHandles.textYH,'String',min(this.myMeasurement.getRawYSz(),val(4)));
            end
        end
        
        function out = get.currentROIVec(this)
            %make ROI vector based on current GUI settings
            switch this.roiMode
                case 1
                    out = [1 this.myMeasurement.getRawXSz() 1 this.myMeasurement.getRawYSz()];
                case 2
                    out = importWizard.getAutoROI(this.myMeasurement.getRawDataFlat(this.selectedCh),2);
                case 3
                    out = this.editFieldROIVec;
            end
        end
        %% Rest
        function this = FLIMXFitResultImport(hFLIMX)
            this.FLIMXObj = hFLIMX;
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.FLIMXFitResultImportFigure) || ~strcmp(get(this.visHandles.FLIMXFitResultImportFigure,'Tag'),'FLIMXFitResultImportFigure'));
        end
        
        function checkVisWnd(this)
            %if not reopen
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.setupGUI();
            this.updateGUI();
            figure(this.visHandles.FLIMXFitResultImportFigure);
        end
        
        function setupGUI(this)
            % popup
            string_list = {};
            for i=1:this.maxCh
                string_list{i}=num2str(i);
            end
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback,'TooltipString','Select channel.','String',string_list);
            % Study / Subject
            set(this.visHandles.popupStudy,'String',this.FLIMXObj.curSubject.myParent.name);
            set(this.visHandles.popupSubject,'String',this.FLIMXObj.curSubject.name);
            set(this.visHandles.editPath,'String',this.folderpath,'Enable','on');
            % show some pictures
            this.selectedCh = 1;
            this.updateColorbar();
            % creaete axes obj
            cm = this.FLIMXObj.FLIMFitGUI.dynVisParams.cmIntensity;
            if(isempty(cm))
                cm = gray(256);
            end
            this.axesMgr = axesWithROI(this.visHandles.axesROI,this.visHandles.axesCb,this.visHandles.textCbBottom,this.visHandles.textCbTop,this.visHandles.editCP,cm);
            a = 2;
        end
        
        function updateGUI(this)
            % selected channel in uitable
            transfer = [{this.allFiles.name}',{this.allFiles.ext}',{this.allFiles.channel}',{this.allFiles.import}',{this.allFiles.fullname}',{this.allFiles.image}'];
            transfer = transfer(cell2mat(transfer(:,3))== this.selectedCh,:);
            set(this.visHandles.tableFiles,'Data',transfer(:,1:4));
            % show selected image
            if (isempty(transfer{this.curRow,6}))
                this.loadImage()
            end
            image = transfer{this.curRow,6};
            
            axes(this.visHandles.axesROI);
            imagesc(image);
            this.updateColorbar();
            %  set(this.visHandles.editPath,'String',this.folderpath,'Enable','off');
        end
        
        
        %% Ask User
        function openFolderByGUI(this)
            %open a new folder using a GUI
            path = uigetdir(this.FLIMXObj.importGUI.lastImportPath,'Select Folder to import data.');
            if(isempty(path) || isequal(path,'0'))
                return
            end
            set(this.visHandles.popupStem,'String','');
            this.getfilesfromfolder(path);
        end
        
        function subjectstem = getSubjectStem(this, pathname)
            stems = get(this.visHandles.popupStem,'String');
            if (isempty(stems))
                files = dir(pathname);
                if (size(files,1) == 0)
                    return
                end
                % call folder selection
                % for each file extension
                maxChan = 16;
                i = 1;
                stem = {};
                while(i <= length(files))
                    [~,filename,curExt] = fileparts(files(i).name);
                    if(strcmp(curExt,'.asc'))
                        idx_= strfind(filename,'_');
                        idxminus = strfind(filename,'-');
                        % Check: 2*'-' and '-_'
                        if (length(strfind(filename,'-'))<2 || idx_(end)~=1+idxminus(end))
                            return % invalid filename
                        end
                        stem{length(stem)+1} = (filename(1:idxminus(end-1)-1));
                    end
                    i = i+1;
                end
                if (~isempty(stem))
                    % find most available word stem
                    singlestem = unique(stem);
                    counter = zeros(length(singlestem));
                    for i=1:length(singlestem)
                        for j=1:length(stem)
                            if (strcmp(singlestem(i),stem(j)))
                                counter(i)=counter(i)+1;
                            end
                        end
                    end
                    [~,place] = max(counter);
                    set(this.visHandles.popupStem,'String',singlestem);
                    subjectstem = singlestem{place(1)};
                else
                    errordlg('Folder doesn''t contain any .asc files. Please choose correct folder.');
                    subjectstem = '';
                end
            else
                subjectstem = stems{get(this.visHandles.popupStem,'Value')};
            end
        end
        
        function getfilesfromfolder(this, pathname)
            files = dir(pathname);
            if (size(files,1) == 0)
                return
            end
            subjectstem = getSubjectStem(this, pathname);
            if (isempty(subjectstem))
                return
            end
            % delete other word stems
            files = files(strncmp({files.name},subjectstem,length(subjectstem)));
            % sort in struct
            fullname = {};
            ext = {};
            channel = {};
            name = {};
            for i=1:length(files)
                [~,filename,curExt] = fileparts(files(i).name);
                ChanNr = [];
                switch curExt
                    case {'.asc', '.bmp', '.tif'}
                        % two digits
                        ChanNr = str2double(filename(length(subjectstem)+4:length(subjectstem)+5));
                        curName = filename(length(subjectstem)+8:length(filename));
                        if (isempty(ChanNr) || isnan(ChanNr))
                            % one digit
                            ChanNr = str2double(filename(length(subjectstem)+4:length(subjectstem)+4));
                            curName = filename(length(subjectstem)+7:length(filename));
                            if (isempty(ChanNr) || isnan(ChanNr))
                                return
                            end
                        end
                end
                if (~contains(curName,'[%]'))
                    channel{i} = ChanNr;
                    ext{i} = curExt;
                    fullname{i} = filename;
                    name{i} = curName;
                end
            end
            ext = ext(~cellfun(@isempty,channel(:)));
            fullname = fullname(~cellfun(@isempty,channel(:)));
            name = name(~cellfun(@isempty,channel(:)));
            channel = channel(~cellfun(@isempty,channel(:)));
            emptyArray = cell(size(ext,2),1);
            falseArray(1:size(ext,2)) = {false};
            this.allFiles = struct('fullname',fullname','ext',ext','channel',channel','name',name','image',emptyArray,'import',falseArray');
            %
            this.folderpath = pathname;
            this.maxCh = max(cell2mat(channel));
            filterindex = 1;
            lastPath = path;
            idx = strfind(lastPath,filesep);
            if(length(idx) > 1)
                lastPath = lastPath(1:idx(end-1));
            end
            this.setupGUI();
            %             for i=1:dim
            %                 files = names_asc(:,i);
            %                 files = files(~cellfun(@isempty,names_asc(:,i)));
            %                 opt.ch = i;
            %                 for i2=1:length(files)
            %                     files{i2} = strcat(files{i2}, '.asc');
            %                 end
            %
            %                 this.files_asc{i} = files;
            %             end
            %
            %             a = 2;
            %             % Set table bmp
            %             [~,dim] = size(names_bmp);
            %             filterindex = 1;
            %             lastPath = path;
            %             idx = strfind(lastPath,filesep);
            %             if(length(idx) > 1)
            %                 lastPath = lastPath(1:idx(end-1));
            %             end
            %             clear files
            %             for i=1:dim
            %                 files = names_bmp(:,i);
            %                 files = files(~cellfun(@isempty,names_bmp(:,i)));
            %                 opt.ch = i;
            %                 for i2=1:length(files)
            %                     files{i2} = strcat(files{i2}, '.bmp');
            %                 end
            %                 this.files_images{i} = files;
            %             end
            
            %  this.dynParams.lastPath = lastPath;
        end
        
        function loadImage(this)
            tStart = clock;
            for i=1:size(this.allFiles,1)
                if (isempty(this.allFiles(i).image) && this.allFiles(i).channel == this.selectedCh)
                    file = fullfile(this.folderpath,[this.allFiles(i).fullname,this.allFiles(i).ext]);
                    switch this.allFiles(i).ext
                        case '.asc'
                            image = dlmread(file);
                        case '.bmp'
                            image = imread(file);
                        case '.tif'
                            image = imread(file);
                    end
                    this.allFiles(i).image = image;
                end
                [hours, minutes, secs] = secs2hms(etime(clock,tStart)/i*(size(this.allFiles,1)-i)); %mean cputime for finished runs * cycles left
                this.plotProgressbar(i/(size(this.allFiles,1)),[],...
                    sprintf('Progress: %02.1f%% - Time left: %dh %dmin %.0fsec - Loading images',...
                    100*i/size(this.allFiles,1),hours,minutes,secs));
            end
            this.plotProgressbar(0,'','');
        end
        
        
        function importall(this)
            
        end
        
        
        
        
        function plotProgressbar(this,x,varargin)
            %update progress bar, progress x: 0..1, varargin{1}: title (currently unused), varargin{2}: text on progressbar
            x = max(0,min(100*x,100));
            %             if(~ishandle(this.visHandles.studyMgrFigure))
            %                 return;
            %             end
            xpatch = [0 x x 0];
            set(this.visHandles.patchProgress,'XData',xpatch,'Parent',this.visHandles.axesProgress)
            if nargin>0,
                % update waitbar
                yl = ylim(this.visHandles.axesProgress);
                set(this.visHandles.textProgress,'Position',[1,yl(2)/2,0],'String',varargin{2},'Parent',this.visHandles.axesProgress);
            end
            drawnow;
        end
        
        
        
        %colorbar
        function updateColorbar(this)
            %update the colorbar to the current color map
            temp = zeros(length(this.FLIMXObj.FLIMVisGUI.dynParams.cm),2,3);
            if(strcmp(this.FLIMXObj.FLIMVisGUI.getFLIMItem('l'),'Intensity'))
                temp(:,1,:) = gray(size(temp,1));
            else
                temp(:,1,:) = this.FLIMXObj.FLIMVisGUI.dynParams.cm;
            end
            if(strcmp(this.FLIMXObj.FLIMVisGUI.getFLIMItem('r'),'Intensity'))
                temp(:,2,:) = gray(size(temp,1));
            else
                temp(:,2,:) = this.FLIMXObj.FLIMVisGUI.dynParams.cm;
            end
            image(temp,'Parent',this.visHandles.cm_axes);
            ytick = (0:0.25:1).*size(this.FLIMXObj.FLIMVisGUI.dynParams.cm,1);
            ytick(1) = 1;
            set(this.visHandles.cm_axes,'YDir','normal','YTick',ytick,'YTickLabel','','YAxisLocation','right','XTick',[],'XTickLabel','');
            ylim(this.visHandles.cm_axes,[1 size(this.FLIMXObj.FLIMVisGUI.dynParams.cm,1)]);
            %??????  setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.cm_axes,false);
        end
    end
    
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            % make a window for visualization of current fit
            this.visHandles = FLIMXFitResultImportFigure();
            figure(this.visHandles.FLIMXFitResultImportFigure);
            %set callbacks
            % popup
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback,'TooltipString','Select channel.');
            set(this.visHandles.popupStem,'Callback',@this.GUI_popupStem_Callback,'TooltipString','Select stem. You will loose your current choice!');
            % table
            %             set(this.visHandles.tableASC,'CellSelectionCallback',@this.GUI_tableASC_CellSelectionCallback);
            %             set(this.visHandles.tableImages,'CellSelectionCallback',@this.GUI_tableImages_CellSelectionCallback);
            %             set(this.visHandles.tableSelected,'CellSelectionCallback',@this.GUI_tableSelected_CellSelectionCallback);
            %             set(this.visHandles.pushDraw,'Callback',@this.GUI_pushDraw_Callback,'TooltipString','Draw selected ASC.');
            set(this.visHandles.tableFiles,'CellSelectionCallback',@this.GUI_tableFiles_CellSelectionCallback);
            % axes
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
            this.visHandles.patchProgress = patch(xpatch,ypatch,'r','EdgeColor','r','Parent',this.visHandles.axesProgress);%,'EraseMode','normal'
            this.visHandles.textProgress = text(1,0,'','Parent',this.visHandles.axesProgress);
            % radiobutton
            set(this.visHandles.radioDefault,'Callback',@this.GUI_radioROI_Callback);
            set(this.visHandles.radioAuto,'Callback',@this.GUI_radioROI_Callback);
            set(this.visHandles.radioCustom,'Callback',@this.GUI_radioROI_Callback);
            % push button
            %             set(this.visHandles.pushSelection,'Callback',@this.GUI_pushSelection_Callback,'TooltipString','Select files.');
            set(this.visHandles.pushBrowse,'Callback',@this.GUI_pushBrowse_Callback,'TooltipString','Browse folder.');
            % checkbox
            set(this.visHandles.checkSelection,'Callback',@this.GUI_checkSelection_Callback,'TooltipString','Select all files for import.');
            % edit fields
            set(this.visHandles.textXL,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textXH,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textYL,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textYH,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.editPath,'Callback',@this.GUI_editPath_Callback,'TooltipString','Write filepath.');
            % mouse
            %             set(this.visHandles.FLIMXFitResultImportFigure,'WindowButtonDownFcn',@this.GUI_mouseButtonDown_Callback);
            %             set(this.visHandles.FLIMXFitResultImportFigure,'WindowButtonUpFcn',@this.GUI_mouseButtonUp_Callback);
            %             set(this.visHandles.FLIMXFitResultImportFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);
            % get user information
            this.openFolderByGUI();
            this.setupGUI();
        end
        
        function updateROIControls(this,roi)
            %apply limits to roi points and update roi display in GUI
            if(isempty(roi))
                roi = this.editFieldROIVec;
            end
            if(roi(4) <= this.myMeasurement.getRawYSz() && roi(2) <= this.myMeasurement.getRawXSz())
                data = this.myMeasurement.getRawDataFlat(this.selectedCh);
                if(~isempty(data))
                    data = data(roi(3):roi(4),roi(1):roi(2));
                end
            else
                data = [];
            end
            total = sum(data(:));
            set(this.visHandles.editTotalPh,'String',sprintf('%.2f million',total/1000000));
            set(this.visHandles.editAvgPh,'String',num2str(total/numel(data),'%.2f'));
            %this.FLIMXObj.FLIMFitGUI.plotRawDataROI(this.visHandles.axesROI,
            this.axesMgr.drawROIBox(roi);
            set(this.visHandles.textXWidth,'String',num2str(1+abs(roi(1)-roi(2))));
            set(this.visHandles.textYWidth,'String',num2str(1+abs(roi(3)-roi(4))));
        end
        %% GUI Callbacks
        % Tables
        function GUI_tableSelected_CellSelectionCallback(this,hObject,eventdata)
            if (isempty(eventdata.Indices))
                row = 1;
            else
                row = eventdata.Indices(1);
            end
            Data=get(this.visHandles.tableSelected, 'Data');
            file=Data(row,1);
            this.curRow = Data{row,2};
            this.updateGUI();
        end
        
        function GUI_tableFiles_CellSelectionCallback(this,hObject, eventdata)
            % which file is selected
            if (isempty(eventdata.Indices))
                row = 1;
                if (this.curCol == 4)
                    % in case of re-call through updateGUI, because of
                    % refreshing files in table, row from "previous"
                    % selection is remembered
                    row = this.curRow;
                end
                col = 1;
            else
                row = eventdata.Indices(1);
                col = eventdata.Indices(2);
            end
            this.curRow = row;
            this.curCol = col;
            % update GUI
            transfer = [{this.allFiles.name}',{this.allFiles.ext}',{this.allFiles.channel}',{this.allFiles.import}',{this.allFiles.fullname}'];
            data = get(this.visHandles.tableFiles,'Data');
            if (col == 4) % mark selected
                data(row,4) = {~logical(cell2mat(data(row,4)))};
            end
            transfer(cell2mat(transfer(:,3))== this.selectedCh,4) = data(:,4);
            for i=1:size(transfer,1)
                this.allFiles(i).import = logical(transfer{i,4});
            end
            this.updateGUI();
        end
        % edit
        function GUI_editPath_Callback(this,hObject,eventdata)
            path = get(this.visHandles.editPath,'String');
            if(isempty(path))
                path = uigetdir(this.FLIMXObj.importGUI.lastImportPath,'Select Folder to import data.');
            end
            set(this.visHandles.popupStem,'String','');
            this.getfilesfromfolder(path);
        end
        
        function GUI_editROI_Callback(this,hObject, eventdata)
            %
            this.isDirty(1) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
            this.finalROIVec = this.editFieldROIVec;
            this.updateROIControls([]);
        end
        % Popup
        function GUI_popupChannel_Callback(this,hObject, eventdata)
            this.selectedCh=get(this.visHandles.popupChannel,'Value');
        end
        
        function GUI_popupStem_Callback(this,hObject, eventdata)
            this.curRow = 1;
            this.curCol = 1;
            this.selectedCh = 1;
            this.getfilesfromfolder(this.folderpath);
        end
        % Pushbutton
        function GUI_pushDraw_Callback(this,hObject, eventdata)
            
        end
        function GUI_pushBrowse_Callback(this,hObject, eventdata)
            this.openFolderByGUI();
            this.setupGUI();
        end
        function GUI_pushSelection_Callback(this,hObject, eventdata)
            file = get(this.visHandles.tableSelected,'Data');
            f1 = file(:,1);
            f2 = file(:,2);
            f3 = file(:,3);
            f1 = f1(~cellfun(@isempty,f1));
            f2 = f2(~cellfun(@isempty,f2));
            f3 = f3(~cellfun(@isempty,f3));
            
            file = [f1, f2, f3 ];
            if (isempty(find(ismember(f1,this.curName{1}))))
                file(end+1,1:3) = [this.curName, this.curRow, this.selectedCh];
            else
                msgbox('File is already selected.', 'Already selected');
            end
            set(this.visHandles.tableSelected,'Data',file);
            
        end
        
        % checkbox
        function GUI_checkSelection_Callback(this,hObject, eventdata)
            transfer = [{this.allFiles.name}',{this.allFiles.ext}',{this.allFiles.channel}',{this.allFiles.import}',{this.allFiles.fullname}'];
            data = get(this.visHandles.tableFiles,'Data');
            data = data(:,4);
            
            % switch checkbox and select all/deselect all
            val = get(this.visHandles.checkSelection,'Value');
            if (val)
                data(1:end) = {true};
                set(this.visHandles.checkSelection,'String','Deselect all.','TooltipString','Click to deselect all files.');
            else
                data(1:end) = {false};
                set(this.visHandles.checkSelection,'String','Select all.','TooltipString','Click to select all files.');
            end
            
            % show
            transfer(cell2mat(transfer(:,3))== this.selectedCh,4) = data(:,1);
            for i=1:size(transfer,1)
                this.allFiles(i).import = logical(transfer{i,4});
            end
            data = get(this.visHandles.tableFiles,'Data');
            set(this.visHandles.tableFiles,'Data',data);
            this.updateGUI();
        end
        
        %radio button
        function GUI_radioROI_Callback(this,hObject, eventdata)
            %
            switch get(hObject,'Tag')
                case 'radioAuto'
                    this.roiMode = 2;
                case 'radioCustom'
                    this.roiMode = 3;
                otherwise
                    %should not happen, we assume default = whole dataset
                    this.roiMode = 1;
            end
            this.isDirty(4) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
            this.isDirty(1) = true;
            roi = this.currentROIVec;
            this.editFieldROIVec = roi;
            this.finalROIVec = roi;
            this.updateGUI();
        end
        
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %mouse callbacks
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function GUI_mouseButtonDown_Callback(this, hObject, eventdata)
            %executes on click in window
            if(this.roiMode ~= 3)
                return;
            end
            cp = get(this.visHandles.axesROI,'CurrentPoint');
            cp = cp(logical([1 1 0; 0 0 0]));
            if(any(cp(:) < 0))
                return;
            end
            set(this.visHandles.textXL,'String',round(abs(cp(1))));
            set(this.visHandles.textYL,'String',round(abs(cp(2))));
            this.buttonDown = true;
        end
        
        function GUI_mouseMotion_Callback(this, hObject, eventdata)
            %executes on mouse move in window
            cp = get(this.visHandles.axesROI,'CurrentPoint');
            cp = cp(logical([1 1 0; 0 0 0]));
            if(any(cp(:) < 0))
                set(this.visHandles.FLIMXFitResultImportFigure,'Pointer','arrow');
                this.editFieldROIVec = this.finalROIVec;
                this.updateROIControls([]);
                return;
            end
            cp=fix(cp+0.52);
            if(cp(1) >= 1 && cp(1) <= this.myMeasurement.getRawYSz() && cp(2) >= 1 && cp(2) <= this.myMeasurement.getRawXSz())
                %inside axes
                set(this.visHandles.FLIMXFitResultImportFigure,'Pointer','cross');
                if(this.buttonDown)
                    set(this.visHandles.textXH,'String',round(abs(cp(1))));
                    set(this.visHandles.textYH,'String',round(abs(cp(2))));
                    roi = [str2double(get(this.visHandles.textXL,'String')), cp(1),...
                        str2double(get(this.visHandles.textYL,'String')), cp(2)];
                    this.updateROIControls(roi);
                else
                    set(this.visHandles.textXL,'String',round(abs(cp(1))));
                    set(this.visHandles.textYL,'String',round(abs(cp(2))));
                end
                %update current point field
                raw = this.myMeasurement.getRawDataFlat(this.selectedCh);
                if(~isempty(raw))
                    set(this.visHandles.editCP,'String',num2str(raw(cp(2),cp(1))));
                end
            else
                set(this.visHandles.FLIMXFitResultImportFigure,'Pointer','arrow');
                this.editFieldROIVec = this.finalROIVec;
                this.updateROIControls([]);
            end
        end
        
        function GUI_mouseButtonUp_Callback(this, hObject, eventdata)
            %executes on click in window
            if(this.roiMode ~= 3)
                return;
            end
            cp = get(this.visHandles.axesROI,'CurrentPoint');
            cp = cp(logical([1 1 0; 0 0 0]));
            if(any(cp(:) < 0))
                return;
            end
            this.buttonDown = false;
            cXl = str2double(get(this.visHandles.textXL,'String'));
            cXu = round(abs(cp(1)));
            cYl = str2double(get(this.visHandles.textYL,'String'));
            cYu = round(abs(cp(2)));
            this.editFieldROIVec = [min(cXl,cXu), max(cXl,cXu), min(cYl,cYu), max(cYl,cYu)];
            this.finalROIVec = this.editFieldROIVec;
            this.isDirty(1) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
            this.updateROIControls([]);
        end
    end
    methods(Static)
        function roi = getAutoROI(imgFlat,roiBinning)
            %try to determine a reasonable ROI
            if(isempty(imgFlat))
                roi = [];
                return
            end
            th = sum(imgFlat(:) / numel(imgFlat));
            bin = imgFlat >= th*0.5; %fitParams.roi_autoThreshold;
            bin =  imerode(bin,strel('square', max(1,roiBinning)));
            xl = find(any(bin,1),1,'first');
            xh = find(any(bin,1),1,'last');
            yl = find(any(bin,2),1,'first');
            yh = find(any(bin,2),1,'last');
            bin = bin(yl:yh,xl:xh);
            %finetune a bit
            rows = sum(bin,2) > size(bin,1)/10;
            cols = sum(bin,1) > size(bin,2)/10;
            xl_old = xl;
            yl_old = yl;
            xl = xl_old-1+find(cols,1,'first');
            xh = xl_old-1+find(cols,1,'last');
            yl = yl_old-1+find(rows,1,'first');
            yh = yl_old-1+find(rows,1,'last');
            roi = [xl xh yl yh];
        end
    end
end

