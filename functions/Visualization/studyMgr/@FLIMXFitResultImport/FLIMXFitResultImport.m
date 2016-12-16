classdef FLIMXFitResultImport < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(GetAccess = public, SetAccess = private)
        FLIMXObj = [];
        visHandles = [];
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
        end
        
        function set.selectedCh(this,val)
            if(~this.isOpenVisWnd() || ~ischar(val))
                return
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
        end
        function updateGUI(this)
        end
        
        %% Callbacks
        function GUI_tableASC_CellSelectionCallback(this,hObject, eventdata)
            row = eventdata.Indices(1);
            Data=get(this.visHandles.tableASC, 'Data');
            file=Data(row,1);
            image = dlmread(file{1});
            axes(this.visHandles.axesROI);
            imshow(image);
            a = 22;
        end
        function GUI_tableImages_CellSelectionCallback(this,hObject, eventdata)
            row = eventdata.Indices(1);
            Data=get(this.visHandles.tableImages, 'Data');
            file=Data(row,1);
            a= 22;
            image = imread(file{1});
            axes(this.visHandles.axesROI);
            imshow(image);
            b = 23;
            
        end
        function GUI_popupChannel_Callback(this,hObject, eventdata)
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
            [~,dim] = size(names_asc);
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
                set(this.visHandles.tableASC,'Data',fullfile(path,files));
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
            for i=1:dim
                files = names_bmp(:,i);
                files = files(~cellfun(@isempty,names_bmp(:,i)));
                opt.ch = i;
                for i2=1:length(files)
                    files{i2} = strcat(files{i2}, '.bmp');
                end;
                set(this.visHandles.tableImages,'Data',fullfile(path,files));
            end;
            a = 2;
            %  this.dynParams.lastPath = lastPath;
            
        end
    end
    
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            %make a window for visualization of current fit
            this.visHandles = FLIMXFitResultImportFigure();
            figure(this.visHandles.FLIMXFitResultImportFigure);
            %set callbacks
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback,'TooltipString','Select channel.');
            set(this.visHandles.tableASC,'CellSelectionCallback',@this.GUI_tableASC_CellSelectionCallback);
            set(this.visHandles.tableImages,'CellSelectionCallback',@this.GUI_tableImages_CellSelectionCallback);
            set(this.visHandles.pushDraw,'Callback',@this.GUI_pushDraw_Callback,'TooltipString','Draw selected ASC.');
            this.getfilesfromfolder();
            a = 2;
        end
    end
    
end

