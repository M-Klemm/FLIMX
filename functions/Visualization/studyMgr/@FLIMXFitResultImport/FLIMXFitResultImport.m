classdef FLIMXFitResultImport < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(GetAccess = public, SetAccess = private)
        FLIMXObj = [];
        visHandles = [];
        allFiles = struct;
        headnames = {'fullname','ext','channel','name','image','bin','import'};
        % read
        folderpath = '';
        maxCh = [];
        curRow = '';
        % Bin
        binFact = 1;
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
%                          transfer = [{this.allFiles.name}',{this.allFiles.ext}',{this.allFiles.channel}',{this.allFiles.import}'];
%                          transfer = transfer(cell2mat(transfer(:,3))== this.selectedCh,:);
%                          set(this.visHandles.tableFiles,'Data',transfer);
            this.curRow = 1;
            this.updateGUI();
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
        
       function closeVisWnd(this)
            %try to close windows if it still exists
            try
                close(this.visHandles.FLIMXFitResultImportFigure);
            end
        end %closeVisWnd
        
        function setupGUI(this)
            % popup
            string_list = {};
            for i=1:this.maxCh
                string_list{i}=num2str(i);
            end
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback,'TooltipString','Select channel.','String',string_list);
            % Study / Subject
            set(this.visHandles.popupStudy,'String',this.FLIMXObj.studyMgrGUI.visHandles.popupStudySelection.String,'Value',this.FLIMXObj.studyMgrGUI.visHandles.popupStudySelection.Value);
            set(this.visHandles.popupSubject,'String',this.FLIMXObj.studyMgrGUI.visHandles.popupSubjectSelection.String,'Value',this.FLIMXObj.studyMgrGUI.visHandles.popupSubjectSelection.Value);
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
            % TODO: struct2cell statt transfer
            
            % selected channel in uitable
            transfer = [{this.allFiles.name}',{this.allFiles.ext}',{this.allFiles.channel}',{this.allFiles.bin}',{this.allFiles.import}',{this.allFiles.fullname}',{this.allFiles.image}'];
            sumImports(1,1) = sum([transfer{:,5}]);
            sumImports(2,1) = size(transfer,1);
            transfer = transfer(cell2mat(transfer(:,3))== this.selectedCh,:);
            sumImports(1,2) = sum([transfer{:,5}]);
            sumImports(2,2) = size(transfer,1);
            set(this.visHandles.tableFiles,'Data',transfer(:,1:5));
            % show selected image
            if (isempty(transfer{this.curRow,7}))
                this.loadImage()
            end
            img = transfer{this.curRow,7};
            axes(this.visHandles.axesROI);
            imagesc(img);
            if (~this.FLIMXObj.FLIMVisGUI.generalParams.reverseYDir)
                this.visHandles.axesROI.YDir = 'normal';
            else
                this.visHandles.axesROI.YDir = 'reverse';
            end 
            % colorbar
            this.updateColorbar();
            % text
            set(this.visHandles.textNumberImports,'String',...
                ['Number of Imports in total: ',num2str(sumImports(1,1)), ...
                '/', num2str(sumImports(2,1))]);
            set(this.visHandles.textNumberImportsChannel,'String',...
                ['Number of Imports for this channel: ',num2str(sumImports(1,2)), ...
                '/', num2str(sumImports(2,2))]);    
        end
        
        
        %% Ask User
        function openFolderByGUI(this)
            %open a new folder using a GUI
            path = uigetdir(this.FLIMXObj.importGUI.lastImportPath,'Select Folder to import data.');
            if(isempty(path) || isequal(path,0))
                msgbox({'No path was chosen!'},'Error','error');
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
                    msgbox({'Path does not contain any files!'},'Error','error');
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
                            msgbox({'Invalid filename found in folder!'},'Error','error');
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
                msgbox({'Folder does not contain any files!'},'Error','error');
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
            tStart = clock;
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
                [hours, minutes, secs] = secs2hms(etime(clock,tStart)/i*(length(files)-i)); %mean cputime for finished runs * cycles left
                this.plotProgressbar(i/(length(files)),[],...
                    sprintf('Progress: %02.1f%% - Time left: %dh %dmin %.0fsec - Reading from files from folder',...
                    100*i/length(files),hours,minutes,secs));
            end
            this.plotProgressbar(0,'','');
            ext = ext(~cellfun(@isempty,channel(:)));
            fullname = fullname(~cellfun(@isempty,channel(:)));
            name = name(~cellfun(@isempty,channel(:)));
            channel = channel(~cellfun(@isempty,channel(:)));
            emptyArray = cell(size(ext,2),1);
            falseArray(1:size(ext,2)) = {false};
            trueArray(1:size(ext,2)) = {true};
            this.allFiles = struct('fullname',fullname','ext',ext','channel',channel','name',name','image',emptyArray,'bin',falseArray','import',trueArray');
            this.folderpath = pathname;
            this.maxCh = max(cell2mat(channel));
            for i=1:this.maxCh
                this.matchingImportsInitialize(i);
            end
            %
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
                    [y,x] = size(this.FLIMXObj.curSubject.myResult.results.pixel{1, 1}.Amplitude1);
                    [ym,xm,~] = size(image);
                    if(ym == y && xm == x)
                        %nothing to do
                    elseif(y/ym - x/xm < eps)
                        %resize image
                        image = imresize(image,[y,x]);
                    else
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
        
        
        function importAll(this)
% flag = this.checkSubjectID(1)
            this.createBinFiles();
            this.updateGUI();
            importResult();
        end
        function flag = checkSubjectID(this, Ch)
            %check if channel ch of subject is already in tree
            [~, resultChs] = this.FLIMXObj.fdt.getSubjectFilesStatus(this.FLIMXObj.curSubject.myParent.name,this.FLIMXObj.curSubject.name);

            flag = any(resultChs == Ch);
        end
        function createBinFiles(this)
            N = length(this.allFiles);
            for i=1:N
                if (~isequal(this.allFiles(i).ext,'.asc') && this.allFiles(i).bin && this.allFiles(i).import)
                    this.allFiles(end+1) = this.allFiles(i);
                    this.allFiles(end).fullname = [this.allFiles(i).fullname, '_BIN'];
                    this.allFiles(end).name = [this.allFiles(i).name, '_BIN'];
                    image = this.allFiles(i).image;
                    %add a second version of the image/mask with binning n
                    image(:,:) = imdilate(image(:,:),true(2*this.binFact+1));
                    this.allFiles(end).image = image;
                end
            end
        end
        
        function lookingForBin(this)
            % enables editBin
            transfer = struct2cell(this.allFiles);
            if (any(cell2mat(transfer(6,:))))
                set(this.visHandles.editBin,'Enable','on');
            else
                set(this.visHandles.editBin,'Enable','off');
            end       
        end
        
        function matchingImportsInitialize(this, Channel)
            transfer_all = struct2cell(this.allFiles);
            transfer = transfer_all(:,cell2mat(transfer_all(3,:))== Channel);
            pos_t1 = strcmp(transfer(4,:),'t1');
            pos_a1 = strcmp(transfer(4,:),'a1');
            pos_t2 = strcmp(transfer(4,:),'t2');
            pos_a2 = strcmp(transfer(4,:),'a2');
            if (~any(pos_a1))
                transfer(7,pos_t1) = {0};
            end
            if (~any(pos_t1))
                transfer(7,pos_a1) = {0};
            end
            if (~any(pos_a2))
                transfer(7,pos_t2) = {0};
            end
            if (~any(pos_t2))
                transfer(7,pos_a2) = {0};
            end
            transfer_all(:,cell2mat(transfer_all(3,:))== Channel) = transfer;
            this.allFiles = cell2struct(transfer_all,this.headnames,1);
        end
        
        function matchingImports(this)
            transfer = struct2cell(this.allFiles);
            data = get(this.visHandles.tableFiles,'Data');
            name = data(this.curRow,1);
            importFlag = data(this.curRow,5);
            switch name{1}
                case 'a1'
                    % change t1
                    pos = strcmp(data(:,1),'t1');                    
                case 'a2'
                    % change t2
                    pos = strcmp(data(:,1),'t2'); 
                case 't1'
                    % change a1
                    pos = strcmp(data(:,1),'a1'); 
                case 't2'
                    % change a2
                    pos = strcmp(data(:,1),'a2');
                otherwise
                    pos = strcmp(data(:,1),name{1});
            end
            if (isequal(pos,zeros(size(data,1),1)))
                % not matching amplitude and tau
                uiwait(errordlg('Number of Amplitudes and Taus does not match! Your last choice has been reset.','Error'));
                pos(this.curRow) = 1;
                importFlag = {0};
            end
            data(pos,5) = importFlag;           
            transfer(6:7,cell2mat(transfer(3,:))== this.selectedCh) = data(:,4:5)';
            this.allFiles = cell2struct(transfer,this.headnames,1);
        end
        
        function plotProgressbar(this,x,varargin)
            %update progress bar, progress x: 0..1, varargin{1}: title (currently unused), varargin{2}: text on progressbar
            x = max(0,min(100*x,100));
            %             if(~ishandle(this.visHandles.studyMgrFigure))
            %                 return;
            %             end
            xpatch = [0 x x 0];
            set(this.visHandles.patchProgress,'XData',xpatch,'Parent',this.visHandles.axesProgress)
            if (nargin>0)
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
            set(this.visHandles.tableFiles,'CellSelectionCallback',@this.GUI_tableFiles_CellSelectionCallback);
            set(this.visHandles.tableFiles,'CellEditCallback',@this.GUI_tableFiles_CellEditCallback);
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
%             set(this.visHandles.radioDefault,'Callback',@this.GUI_radioROI_Callback);
%             set(this.visHandles.radioAuto,'Callback',@this.GUI_radioROI_Callback);
%             set(this.visHandles.radioCustom,'Callback',@this.GUI_radioROI_Callback);
            % push button
            set(this.visHandles.pushBrowse,'Callback',@this.GUI_pushBrowse_Callback,'TooltipString','Browse folder.');
            set(this.visHandles.pushImport,'Callback',@this.GUI_pushImport_Callback,'TooltipString','If you are ready, click here to import all selected files from all channels for the selected stem.');
            set(this.visHandles.pushCancel,'Callback',@this.GUI_pushCancel_Callback,'TooltipString','Click here for cancel importing resultfiles.');
            % checkbox
            set(this.visHandles.checkSelection,'Callback',@this.GUI_checkSelection_Callback,'TooltipString','Select all files for import.');
            % edit fields
            set(this.visHandles.textXL,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textXH,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textYL,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textYH,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.editPath,'Callback',@this.GUI_editPath_Callback,'TooltipString','Write filepath.');
            set(this.visHandles.editBin,'Callback',@this.GUI_editBin_Callback,'TooltipString','Binfactor must be real number greater 1.','String','1','Enable','off');
            % mouse
%                          set(this.visHandles.FLIMXFitResultImportFigure,'WindowButtonDownFcn',@this.GUI_mouseButtonDown_Callback);
%                          set(this.visHandles.FLIMXFitResultImportFigure,'WindowButtonUpFcn',@this.GUI_mouseButtonUp_Callback);
%                          set(this.visHandles.FLIMXFitResultImportFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);
            % start task
            this.openFolderByGUI();
            this.setupGUI();
        end
        
        %% GUI Callbacks
        % Tables
        function GUI_tableFiles_CellSelectionCallback(this,hObject, eventdata)
            if (isempty(eventdata.Indices))
                return
            else
                row = eventdata.Indices(1);
            end
            this.curRow = row;
            this.updateGUI();
        end
        function GUI_tableFiles_CellEditCallback(this,hObject, eventdata)
            % which file is selected
            if (isempty(eventdata.Indices))
                row = 1;
            else
                row = eventdata.Indices(1);
            end
            this.curRow = row;
            % update GUI
            transfer = struct2cell(this.allFiles);
            data = eventdata.Source.Data;
            transfer(6:7,cell2mat(transfer(3,:))== this.selectedCh) = data(:,4:5)';
            this.allFiles = cell2struct(transfer,this.headnames,1);
            % bin enable
            if (isequal(4,eventdata.Indices(2)))
                this.lookingForBin();
            end
            % select/deselect matching files
            if (isequal(5,eventdata.Indices(2)))
                this.matchingImports();
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
        
        function GUI_editBin_Callback(this,hObject,eventdata)
            binFactor = str2double(get(this.visHandles.editBin,'String'));
            if(isempty(binFactor) || isnan(binFactor))
                binFactor = 1;
            end
            binFactor(binFactor < 1) = 1;
            binFactor(binFactor > 9) = 9;
            binFactor = round(binFactor,0);
            set(this.visHandles.editBin,'String',binFactor);
            this.binFact = binFactor;
        end
        
        function GUI_editROI_Callback(this,hObject, eventdata)
            %
            this.isDirty(1) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
            this.finalROIVec = this.editFieldROIVec;
            this.updateROIControls([]);
        end
        
        % Popup
        function GUI_popupChannel_Callback(this,hObject, eventdata)
            this.selectedCh = get(this.visHandles.popupChannel,'Value');
        end
        
        function GUI_popupStem_Callback(this,hObject, eventdata)
            this.curRow = 1;
            this.selectedCh = 1;
            this.getfilesfromfolder(this.folderpath);
        end
        
        % Pushbutton
        function GUI_pushBrowse_Callback(this,hObject, eventdata)
            this.openFolderByGUI();
            this.setupGUI();
        end
        function GUI_pushCancel_Callback(this,hObject, eventdata)
            this.closeVisWnd();
        end
        function GUI_pushImport_Callback(this,hObject, eventdata)
            studyNames = get(this.visHandles.popupStudy,'String');
            subjectNames = get(this.visHandles.popupSubject,'String');
            answer = questdlg(['Do you want to import all selected files for Subject ''', ...
                subjectNames{get(this.visHandles.popupSubject,'Value')}, ...
                ''' in Study ''',studyNames{get(this.visHandles.popupStudy,'Value')},'''?'],...
                'Continue?','Yes','No','No');
            switch answer
                case 'Yes'
                    this.importAll();
                otherwise
            end
        end
        
        % checkbox
        function GUI_checkSelection_Callback(this,hObject, eventdata)
            transfer = struct2cell(this.allFiles);
            % switch checkbox and select all/deselect all
            val = get(this.visHandles.checkSelection,'Value');
            if (val)
                data(1:length(get(this.visHandles.tableFiles,'Data'))) = {true};
                transfer(7,cell2mat(transfer(3,:))== this.selectedCh) = data;
                this.allFiles = cell2struct(transfer,this.headnames,1);
                this.matchingImportsInitialize(this.selectedCh);
                set(this.visHandles.checkSelection,'String','Deselect all.','TooltipString','Click to deselect all files.');
            else
                data(1:length(get(this.visHandles.tableFiles,'Data'))) = {false};
                set(this.visHandles.checkSelection,'String','Select all.','TooltipString','Click to select all files.');    
                % show
                transfer(7,cell2mat(transfer(3,:))== this.selectedCh) = data;
                this.allFiles = cell2struct(transfer,this.headnames,1);
            end
            this.updateGUI();
        end
        
                function GUI_checkBin_Callback(this,hObject, eventdata)
            
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
end

