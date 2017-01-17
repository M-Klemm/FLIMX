classdef FLIMXFitResultImport < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(GetAccess = public, SetAccess = private)
        FLIMXObj = [];
        visHandles = [];
        files_asc = {};
        files_images = {};
        folderpath = '';
        maxCh = [];
    end
    
    properties (Dependent = true)
        selectedCh = 1;
    end
    methods
        %% dependent properties
        function out = get.selectedCh(this)
            %get current selected channel
            if(~this.isOpenVisWnd())
                return
            end
            out = str2double(get(this.visHandles.popupChannel,'Value'));
        end
        
        function set.selectedCh(this,val)
            if(~this.isOpenVisWnd())% || ~ischar(val))
                return
            end
            val(val>this.maxCh)=this.maxCh;
            set(this.visHandles.popupChannel,'Value',val);
            set(this.visHandles.tableASC,'Data',this.files_asc{val});
            val(val>size(this.files_images,2))=size(this.files_images,2);
            set(this.visHandles.tableImages,'Data',this.files_images{val});
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
        end
        function updateGUI(this)
        end
        
        %% Callbacks
        function GUI_tableASC_CellSelectionCallback(this,hObject,eventdata)
            if isempty(eventdata.Indices)
                row = 1;
            else
                row = eventdata.Indices(1);
            end
            Data=get(this.visHandles.tableASC, 'Data');
            file=Data(row,1);
            image = dlmread(fullfile(this.folderpath,file{1}));
            axes(this.visHandles.axesROI);
            imshow(image);
            a = 22;
        end
        function GUI_tableImages_CellSelectionCallback(this,hObject, eventdata)
            row = eventdata.Indices(1);
            Data=get(this.visHandles.tableImages, 'Data');
            file=Data(row,1);
            image = imread(fullfile(this.folderpath,file{1}));
            axes(this.visHandles.axesROI);
            imshow(image);
            b = 23;
            
        end
        function GUI_popupChannel_Callback(this,hObject, eventdata)
            this.selectedCh=get(this.visHandles.popupChannel,'Value');
        end
        function GUI_pushDraw_Callback(this,hObject, eventdata)
            
        end
        %% Ask User
        function getfilesfromfolder(this)
            pathname = uigetdir('', 'Choose folder');
            if pathname == 0
                return
            end;
            files = dir(pathname);
            if size(files,1) == 0
                return
            end;
            % call folder selection
            % for each file extension
            names_asc = {};
            names_bmp = {};
            names_tif = {};
            maxChan = 16;
            column_asc = zeros(maxChan,1);
            column_bmp = zeros(maxChan,1);
            column_tif = zeros(maxChan,1);
            i = 1;
            stem = {};
            while(i <= length(files))
                [~,filename,ext] = fileparts(files(i).name);
                if(strcmp(ext,'.asc'))
                    idx_= strfind(filename,'_');
                    idxminus = strfind(filename,'-');
                    % Check: 2*'-' and '-_'
                    if length(strfind(filename,'-'))<2 || idx_(end)~=1+idxminus(end)
                        return % invalid filename
                    end;
                    stem{length(stem)+1} = (filename(1:idxminus(end-1)-1));
                end;
                i = i+1;
            end;
            % find most available word stem
            singlestem = unique(stem);
            counter = zeros(length(singlestem));
            for i=1:length(singlestem)
                for j=1:length(stem)
                    if strcmp(singlestem(i),stem(j))
                        counter(i)=counter(i)+1;
                    end;
                end;
            end;
            [~,place] = max(counter);
            subjectstamm = singlestem{place(1)};
            % delete other word stems
            files = files(strncmp({files.name},subjectstamm,length(subjectstamm)));
            % sort every file
            for i=1:length(files)
                if files(i).isdir == false
                    fullfilename = files(i).name;
                    [~,filename,ext] = fileparts(fullfilename);
                    aktstamm = filename(1:length(subjectstamm));
                    if aktstamm == subjectstamm
                        switch ext
                            case {'.asc', '.bmp', '.tif'}
                                % two digits
                                ChanNr = str2double(filename(length(subjectstamm)+4:length(subjectstamm)+5));
                                if isempty(ChanNr) || isnan(ChanNr)
                                    % one digit
                                    ChanNr = str2double(filename(length(subjectstamm)+4:length(subjectstamm)+4));
                                    if isempty(ChanNr) || isnan(ChanNr)
                                        return
                                    end;
                                end;
                                switch ext
                                    case '.asc'
                                        column_asc(ChanNr)=column_asc(ChanNr)+1;
                                        names_asc{column_asc(ChanNr),ChanNr}=filename;
                                    case '.bmp'
                                        column_bmp(ChanNr)=column_bmp(ChanNr)+1;
                                        names_bmp{column_bmp(ChanNr),ChanNr}=filename;
                                    otherwise % '.tif'
                                        column_tif(ChanNr)=column_tif(ChanNr)+1;
                                        names_tif{column_tif(ChanNr),ChanNr}=filename;
                                end;
                            otherwise
                        end;
                    end;
                end;
            end;
            path = pathname;
            this.folderpath = path;
           % FLIMXFitResultImport.files_asc = names_asc;
            [~,dim] = size(names_asc);
            this.maxCh = dim;
            filterindex = 1;
            lastPath = path;
            idx = strfind(lastPath,filesep);
            if(length(idx) > 1)
                lastPath = lastPath(1:idx(end-1));
            end
            for i=1:dim
                files = names_asc(:,i);
                files = files(~cellfun(@isempty,names_asc(:,i)));
                opt.ch = i;
                for i2=1:length(files)
                    files{i2} = strcat(files{i2}, '.asc');
                end;
                
                this.files_asc{i} = files;
            end;

            a = 2;
            % Set table bmp
            [~,dim] = size(names_bmp);
            filterindex = 1;
            lastPath = path;
            idx = strfind(lastPath,filesep);
            if(length(idx) > 1)
                lastPath = lastPath(1:idx(end-1));
            end
            clear files
            for i=1:dim
                files = names_bmp(:,i);
                files = files(~cellfun(@isempty,names_bmp(:,i)));
                opt.ch = i;
                for i2=1:length(files)
                    files{i2} = strcat(files{i2}, '.bmp');
                end;
              this.files_images{i} = files;
            end;
            a = 2;
            %  this.dynParams.lastPath = lastPath;
            
        end
        
        function importall(this)
            
        end
    end
    
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            %make a window for visualization of current fit
            this.visHandles = FLIMXFitResultImportFigure();
            figure(this.visHandles.FLIMXFitResultImportFigure);
            % get user information
            this.getfilesfromfolder();
            %set callbacks
            string_list = {};
            for i=1:this.maxCh
                string_list{i}=num2str(i);
            end
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback,'TooltipString','Select channel.','String',string_list);
            set(this.visHandles.tableASC,'CellSelectionCallback',@this.GUI_tableASC_CellSelectionCallback);
            set(this.visHandles.tableImages,'CellSelectionCallback',@this.GUI_tableImages_CellSelectionCallback);
            set(this.visHandles.pushDraw,'Callback',@this.GUI_pushDraw_Callback,'TooltipString','Draw selected ASC.');
            % initialisierung
            this.selectedCh = 1;
            a = 2;
        end
    end
end

