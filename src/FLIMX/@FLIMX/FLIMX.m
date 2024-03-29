classdef FLIMX < handle
    %=============================================================================================================
    %
    % @file     FLIMX.m
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
    % @brief    A class to represent the base class FLIM eXplorer, which stores all other objects
    %
    properties(GetAccess = public, SetAccess = private)
        fdt = [];           %FDTree object, our datastorage
        irfMgr = [];        %object to handle IRF access
        paramMgr = [];      %parameter objects
        curSubject = [];    %current subject
        loggerObj = [];     %logger object
        GPUList = [];       %list of compatible GPUs in current PC
    end

    properties(GetAccess = protected, SetAccess = private)
        FLIMFitObj = [];    %approximation object
        sDDMgrObj = [];     %only temporary: manage synthetic datasets
        batchJobMgrObj = [];%batch job manager
        hashEngineObj = []; %MD5 hash engine

        %GUIs
        FLIMFitGUIObj = [];             %visualization of approximation
        FLIMVisGUIObj = [];             %extended visualization and statistics
        studyMgrGUIObj = [];            %manager for subject studies
        irfMgrGUIObj = [];              %GUI to handle IRF access
        batchJobMgrGUIObj = [];         %batch job manager GUI
        importMeasurementGUIObj = [];   %measurement import wizard
        importResultGUIObj = [];        %result import wizard
        matlabPoolTimer = [];           %timer to prevent MATLAB pool shutdown
        fdtAutoSaveTimer = [];          %timer to automatically save changes in a fixed time interval
        splashScreenGUIObj = [];        %splash screen window for FLIMX startup
    end

    properties (Dependent = true)
        configPath = ''; %path to config file
        %objects
        FLIMFit = [];    %approximation object
        sDDMgr = [];     %only temporary: manage synthetic datasets
        batchJobMgr = [];%batch job manager
        logger = [];     %log object
        hashEngine = []; %MD5 hash engine

        FLIMFitGUI = [];        %visualization of approximation
        FLIMVisGUI = [];        %extended visualization and statistics
        studyMgrGUI = [];       %manager for subject studies
        irfMgrGUI = [];         %GUI to handle IRF access
        batchJobMgrGUI = [];    %batch job manager GUI
        importGUI = [];         %import wizard
        importResultGUI = [];   %result import wizard
        splashScreenGUI = [];   %splash screen
    end

    methods
        function this = FLIMX()
            %constructor
            warning('off','MATLAB:rankDeficientMatrix');
            this.loggerObj = logging.getLogger('FLIMXLog','path',fullfile(FLIMX.getWorkingDir(),'log','FLIMX.log'));%,'commandWindowLevel',0);
            this.splashScreenGUIObj = FLIMXSplashScreen();
            this.updateSplashScreenLongProgress(0.01,'Load IRFs...');
            %parameters from ini file
            warning('off','parallel:gpu:DeviceCapabiity');
            %make lower level objects
            this.paramMgr = FLIMXParamMgr(this,FLIMX.getVersionInfo());
            this.irfMgr = IRFMgr(this,fullfile(FLIMX.getWorkingDir(),'data'));
            this.updateSplashScreenLongProgress(0.3,'Build data tree structure...');
            this.fdt = FDTree(this,FLIMX.getWorkingDir()); %replace with path from config?!
            this.updateSplashScreenShortProgress(0,'');
            fp = this.paramMgr.getParamSection('filtering');
            if(fp.ifilter)
                alg = fp.ifilter_type;
                params = fp.ifilter_size;
            else
                alg = 0;
                params = 0;
            end
            this.fdt.setDataSmoothFilter(alg,params);
            this.fdt.maxMemoryCacheSize = this.paramMgr.generalParams.maxMemoryCacheSize;
            %set window size
            if(this.paramMgr.generalParams.autoWindowSize)
                this.paramMgr.generalParams.windowSize = FLIMX.getAutoWindowSize();
            end
            %set max cache size
            if(this.paramMgr.generalParams.maxMemoryCacheSize > FLIMX.getMaxSystemCacheSize())
                this.paramMgr.generalParams.maxMemoryCacheSize = FLIMX.getMaxSystemCacheSize();
            end
            %load a subject
            this.updateSplashScreenLongProgress(0.5,'Load first subject...');
            subs = this.fdt.getAllSubjectNames('Default',FDTree.defaultConditionName());
            if(isempty(subs))
                %todo: generate a dummy subject with simulated data
                this.setCurrentSubject('Default',FDTree.defaultConditionName(),'');
            else
                this.setCurrentSubject('Default',FDTree.defaultConditionName(),subs{1});
            end
            this.updateSplashScreenLongProgress(0.7,'Open pool of MATLAB workers...');
            this.openMatlabPool();
            if(this.paramMgr.computationParams.useGPU)
                this.updateSplashScreenLongProgress(0.8,'Looking for compatible GPUs...');
                this.checkCompatibleGPUs();
            end
            if(this.paramMgr.generalParams.autoSaveInterval > 0)
                %setup timer to automatically save changes
                this.fdtAutoSaveTimer = timer('ExecutionMode','fixedRate','Period',this.paramMgr.generalParams.autoSaveInterval,'TimerFcn',@this.FDTAutoSaveTimerCallback,'Tag','FLIMXFDTAutoSaveTimer');
                start(this.fdtAutoSaveTimer);
            end
            this.updateSplashScreenShortProgress(0,'');
        end

        function openFLIMXFitGUI(this)
            %open FLIMXFitGUI
            this.FLIMFitGUI.checkVisWnd();
        end

        function openFLIMXVisGUI(this)
            %open FLIMVisGUI
            this.FLIMVisGUI.checkVisWnd();
        end

        function openMatlabPool(this)
            %try to open a matlab pool
            computationParams = this.paramMgr.getParamSection('computation');
            p = gcp('nocreate');
            if(computationParams.useMatlabDistComp > 0 && isempty(p))
                %start local matlab workers
                if(ishandle(this.splashScreenGUIObj))
                    this.splashScreenGUIObj.updateShortProgress(0.5,sprintf('MATLAB pool workers can be disabled in Settings -> Computation'));
                end
                try
%                     if(computationParams.useGPU)
%                         %as many workers as GPUs
%                         p = parpool('local',gpuDeviceCount);
%                     else
                        %as many workers as CPU cores
                        nr = version('-release');
                        if(str2double(nr(1:4)) >= 2020 && computationParams.poolType == 2)
                            p = parpool('threads');
                        else
                            p = parpool('local',min(computationParams.maxNrWorkersMatlabDistComp,feature('numCores')));
                        end
%                     end
                    if(~isempty(p))
                        parfevalOnAll(p, @warning, 0, 'off', 'MATLAB:rankDeficientMatrix');
                    end
                    this.splashScreenGUIObj.updateShortProgress(1,'Open pool of MATLAB workers - done');
                catch ME
                    if(ishandle(this.splashScreenGUIObj))
                        this.splashScreenGUIObj.updateShortProgress(1,'Open pool of MATLAB workers - failed');
                    end
                    warning('FLIMX:openMatlabPool','Could not open MATLAB pool for parallel computations: %s',ME.message);
                end
            end
            if(~isempty(p) && ~isa(p,'parallel.ThreadPool'))
                p.IdleTimeout = inf;
%                 this.matlabPoolTimer = timer('ExecutionMode','fixedRate','Period',p.IdleTimeout/2*60,'TimerFcn','FLIMX.MatlabPoolIdleFcn','Tag','FLIMXMatlabPoolTimer');
%                 start(this.matlabPoolTimer);
            end
        end

        function checkCompatibleGPUs(this)
            %look for GPUs in the current system and store the IDs of compatible GPUs
            warning('off','parallel:gpu:DeviceCapability');
            n = gpuDeviceCount;
%             list = [];
%             for i = 1:n
%                 data = gpuDevice(i);
%                 if(~isempty(data) && isfield(data,'DeviceSupported'))
%                     %in the future: check other requirements here (e.g. size of GPU memory)
%                     list = [list, i];
%                 end
%             end
%             this.GPUList = list;
            this.GPUList = find(parallel.gpu.GPUDevice.isAvailable(1:n));
        end

        function closeSplashScreen(this)
            %close splash screen window
            try
                delete(this.splashScreenGUIObj.delete());
            end
            this.splashScreenGUIObj = [];
        end

        function closeMatlabPool(this)
            %try to close our matlab pool
            p = gcp('nocreate');
            if(~isempty(p))% && ~isa(p,'parallel.ThreadPool'))
                %delete idle timer object
                try
                    delete(this.matlabPoolTimer);
                catch
                end
                %delete matlab pool
                delete(p);
            end
        end

        function destroy(this,forceFlag)
            %delete FLIMX object if all windows are closed or if forceFlag == true
            warning('on','MATLAB:rankDeficientMatrix');
            if(forceFlag || (~this.FLIMFitGUI.isOpenVisWnd() && ~this.FLIMVisGUI.isOpenVisWnd()))
                %do some cleanup and save changes
                if(~isempty(this.fdtAutoSaveTimer) && this.fdtAutoSaveTimer.isvalid)
                    stop(this.fdtAutoSaveTimer);
                    delete(this.fdtAutoSaveTimer);
                    this.fdtAutoSaveTimer = [];
                end
                this.fdt.saveAllStudies(false);
                if(~isempty(this.sDDMgrObj) && this.sDDMgrObj.anyDirtySDDs())
                    choice = questdlg('Save changes to simulation parameter sets?','Save Parameter Sets?','Yes','No','Cancel','Yes');
                    switch choice
                        case 'Yes'
                            this.sDDMgrObj.saveAll();
                        case 'No'
                            %load unmodified parameter sets
                            this.sDDMgrObj.scanForSDDs();
                    end
                end
                %close remaining GUIs
                if(~isempty(this.studyMgrGUIObj) && this.studyMgrGUIObj.isvalid)
                    this.studyMgrGUIObj.menuExit_Callback();
                end
                if(~isempty(this.batchJobMgrGUIObj) && this.batchJobMgrGUIObj.isvalid)
                    this.batchJobMgrGUIObj.menuExit_Callback();
                end
                if(~isempty(this.irfMgrGUIObj) && this.irfMgrGUIObj.isvalid)
                    this.irfMgrGUIObj.menuExit_Callback();
                end
                if(~isempty(this.irfMgrGUIObj) && this.irfMgrGUIObj.isvalid)
                    this.irfMgrGUIObj.menuExit_Callback();
                end
                if(~isempty(this.matlabPoolTimer) && this.matlabPoolTimer.isvalid)
                    stop(this.matlabPoolTimer);
                    delete(this.matlabPoolTimer);
                    this.matlabPoolTimer = [];
                end
                %delete me
                delete(this);
                return
            end
        end

        function closeBatchJobMgrGUI(this)
            %close GUI of batch job manager

        end
        %% output methods
        function out = get.configPath(this)
            %config file path
            out = fullfile(FLIMX.getWorkingDir(),'config','config.ini');
        end

        function out = get.FLIMFit(this)
            %get FLIMFit object
            if(isempty(this.FLIMFitObj))
                this.FLIMFitObj = FluoDecayFit(this);
            end
            out = this.FLIMFitObj;
        end

        function out = get.sDDMgr(this)
            %get sDDMgr object
            if(isempty(this.sDDMgrObj))
                this.sDDMgrObj = sddMgr(this,fullfile(FLIMX.getWorkingDir(),'simData')); %replace with path from config?!
            end
            out = this.sDDMgrObj;
        end

        function out = get.batchJobMgr(this)
            %get batchJobMgr object
            if(isempty(this.batchJobMgrObj))
                this.batchJobMgrObj = batchJobMgr(this,fullfile(FLIMX.getWorkingDir(),'batchJobData')); %replace with path from config?!
            end
            out = this.batchJobMgrObj;
        end

        function out = get.FLIMFitGUI(this)
            %get FLIMFitGUI object
            if(isempty(this.FLIMFitGUIObj))
                this.FLIMFitGUIObj = FLIMXFitGUI(this);
            end
            out = this.FLIMFitGUIObj;
        end

        function out = get.splashScreenGUI(this)
            %get splash screen object
            %             if(isempty(this.splashScreenGUIObj))
            %                 this.splashScreenGUIObj = FLIMXSplashScreen();
            %             end
            out = this.splashScreenGUIObj;
        end

        function out = get.FLIMVisGUI(this)
            %get FLIMVisGUI object
            if(isempty(this.FLIMVisGUIObj))
                this.FLIMVisGUIObj = FLIMXVisGUI(this);
            end
            out = this.FLIMVisGUIObj;
        end

        function out = get.studyMgrGUI(this)
            %get studyMgrGUI object
            if(isempty(this.studyMgrGUIObj))
                this.studyMgrGUIObj = studyMgr(this); %replace with path from config?!
            end
            out = this.studyMgrGUIObj;
        end

        function out = get.irfMgrGUI(this)
            %get irfMgrGUI object
            if(isempty(this.irfMgrGUIObj))
                this.irfMgrGUIObj = IRFMgrGUI(this.irfMgr); %replace with path from config?!
            end
            out = this.irfMgrGUIObj;
        end

        function out = get.batchJobMgrGUI(this)
            %get batchMgrGUI object
            if(isempty(this.batchJobMgrGUIObj))
                this.batchJobMgrGUIObj = batchJobMgrGUI(this);
            end
            out = this.batchJobMgrGUIObj;
        end

        function out = get.importGUI(this)
            %get importGUI object
            if(isempty(this.importMeasurementGUIObj))
                this.importMeasurementGUIObj = importWizard(this);
            end
            out = this.importMeasurementGUIObj;
        end

        function out = get.importResultGUI(this)
            %get importResultGUI object
            if(isempty(this.importResultGUIObj))
                this.importResultGUIObj = FLIMXFitResultImport(this);
            end
            out = this.importResultGUIObj;
        end

        function out = get.hashEngine(this)
            %return FLIMX hash engine
            if(isempty(this.hashEngineObj))
                try
                    this.hashEngineObj = java.security.MessageDigest.getInstance('MD5');
                catch
                    this.hashEngineObj = [];
                end
            end
            out = this.hashEngineObj;
        end

        function saveCurResultInFDT(this)
            %save dirty channels of current result in FDTree
            for ch = find(this.curSubject.resultIsDirty)
                this.curSubject.updateSubjectChannel(ch,'result');
                this.fdt.saveStudy(this.curSubject.getStudyName());
            end
        end

        function success = setCurrentSubject(this,study,condition,subject)
            %set the current subject
            success = true;
            studyPos = find(strcmp(study,this.fdt.getAllStudyNames()),1);
            if(isempty(studyPos))
                this.curSubject = this.fdt.getSubject4Import(study,'example_subject');
                success = false;
                return
            end
            if(isempty(subject))
                this.curSubject = this.fdt.getSubject4Import(study,'example_subject');
            else
                subjectPos = find(strcmp(subject,this.fdt.getAllSubjectNames(study,condition)),1);
                if(~isempty(subjectPos) && isempty(this.curSubject) || (~strcmp(this.curSubject.getStudyName(),study) || ~strcmp(this.curSubject.getDatasetName(),subject)))
                    %save old result
                    if(~isempty(this.curSubject) && any(this.curSubject.resultIsDirty))
                        button = questdlg(sprintf('Approximation result was changed. Do you want to save the changes?'),'Approximation Result Changed','Yes','No','Yes');
                        switch button
                            case 'Yes'
                                this.saveCurResultInFDT();
                        end
                    end
                    this.curSubject = this.fdt.getSubject4Approx(study,subject,false);
                    if(isempty(this.curSubject))
                        %we don't have that subject in FDTree -> create a dummy fluoFile object
                        this.curSubject = this.fdt.getSubject4Import(study,'example_subject');
                    end
                    this.curSubject.setProgressCallback(@this.updateFluoDecayFitProgressbar);
                else
                    return
                end
            end
            if(~isempty(this.FLIMFitGUIObj))
                this.FLIMFitGUI.setupGUI(); %make sure popup menus are correct
                %move to pixel with most photons
                img = this.curSubject.getROIDataFlat(this.FLIMFitGUI.currentChannel,true);
                if(~isempty(img))
                    [tmp,yPos] = max(img,[],1,'omitnan');
                    [~,xPos] = max(tmp,[],'omitnan');
                    yPos = yPos(xPos);
                    this.FLIMFitGUI.setCurrentPos(yPos,xPos);
                else
                    this.FLIMFitGUI.updateGUI(true);
                end
                %todo: check irf?!
            end
        end

        function updateFluoDecayFitProgressbar(this,x,text)
            %set progress in FLIMXFitGUI to new value
            this.FLIMFitGUI.updateShortProgress(x,text);
        end

        function updateSplashScreenShortProgress(this,x,text)
            %set short progress in splash screen to new value
            if(~isempty(this.splashScreenGUIObj))
                this.splashScreenGUIObj.updateShortProgress(x,text);
            end
        end

        function updateSplashScreenLongProgress(this,x,text)
            %set short progress in splash screen to new value
            if(~isempty(this.splashScreenGUIObj))
                this.splashScreenGUIObj.updateLongProgress(x,text);
            end
        end

    end %methods

    methods(Access = protected)
        function FDTAutoSaveTimerCallback(this,varargin)
            %FDT auto save time callback
            this.fdt.saveAllStudies(false);
        end
    end

    methods(Static)
        function out = getWorkingDir()
            %get current FLIMX working directory
            persistent myDir
            if(isempty(myDir))
                if(isdeployed)
                    [~, result] = system('set PATH');
                    myDir = char(regexpi(result, 'Path=(.*?);', 'tokens', 'once'));
                else
                    myDir = fileparts(which('FLIMXLauncher.m'));
                end
            end
            out = myDir;
        end

        function out = getAnimationPath()
            %get path to animated spinner.gif
            persistent myDir
            if(isempty(myDir))
                myDir = which('spinner.gif');
            end
            out = myDir;
        end

        function [mapNames, iconPaths] = getColormapsInfo()
            %get names and path to images of color maps, generate color map previews
            persistent cmNames cmPaths
            if(isempty(cmPaths))
                dataDir = [FLIMX.getWorkingDir() filesep 'data'];
                if(~isfolder(dataDir))
                    [status, message, ~] = mkdir(dataDir);
                    if(~status)
                        error('FLIMX:getColormapsInfo','Could not create color map data folder: %s\n%s',dataDir,message);
                    end
                end
                cmNames = {'Autumn','Bone','Colorcube','Cool','Copper','Cividis','Flag','Gray','Hot','Hsv','Inferno','Jet','Lines','Magma','Parula','Pink','Plasma','Prism','Spectrum','SpectrumFixed','Spring','Summer','Twilight','TwilightShifted','Viridis','White','Winter'};
                cmPaths = strcat([dataDir filesep 'colormap_'], cmNames', '.png');
                for i = length(cmPaths):-1:1
                    if(~isfile(cmPaths{i}))
                        %no color map icon found -> generate it
                        map = shiftdim(FLIMX.getColormap(cmNames{i}),-1);
                        if(~isempty(map) && any(map(:)))
                            map = repmat(map,7,1,1);
                            imwrite(map,cmPaths{i});
                        else
                            %color map generation did not work -> remove it from list
                            cmNames = cmNames(1:i-1);
                            cmPaths = cmPaths(1:i-1);
                        end
                    end
                end
            end
            mapNames = cmNames;
            iconPaths = cmPaths;
        end

        function out = getColormap(mapName)
            %return a color map for use in FLIMX
            try
                switch mapName
                case 'SpectrumFixed'
                    %out = zeros(1,401,3);
                    out = spectrumColors;
                case 'Spectrum'
                    %out = zeros(1,272,3); %430 - 700 nm
                    out = spectrumColors;
                    out = out(50:321,:);
                otherwise
                    %out = zeros(1,256,3);
                    eval(sprintf('out = %s(256);',lower(mapName)));
                end
            catch ME
                out = [];
            end
        end

        function out = getLogoPath()
            %get path to FLIMX_Logo.png
            persistent myDir
            if(isempty(myDir))
                myDir = which('FLIMX_Logo.png');
            end
            out = myDir;
        end

        function out = getVersionInfo()
            %get version numbers of FLIMX
            %set current revisions HERE!
            out.config_revision = 279;
            out.client_revision_major = 5;
            out.client_revision_minor = 10;
            out.client_revision_fix = 8;
            out.core_revision = 504;
            out.results_revision = 257;
            out.measurement_revision = 206;
        end

        function out = getAutoWindowSize()
            %determine best window size for current display and set it
            set(0,'units','pixels');
            ss = get(0,'screensize');
            if(ss(3) >= 1750 && ss(4) >= 1050)
                out = 3; %large
            elseif(ss(3) < 1750 && ss(3) >= 1400 && ss(4) >= 900)
                out = 1; %medium
            else %ss(3) < 1720 && ss(4) < 768)
                out = 2; %small
            end
        end

        function out = getMaxSystemCacheSize()
            %determine system memory size and guess a reasonable cache size
            persistent maxSysCacheSz
            if(isempty(maxSysCacheSz))
                if(ispc)
                    [~,sv] = memory;
                    systemRAM = sv.PhysicalMemory.Total;
                else
                    %thanks to angainor: https://stackoverflow.com/questions/12350598/how-to-access-memory-information-in-matlab-on-unix-equivalent-of-user-view-max
                    [~,w] = unix('free | grep Mem');
                    stats = str2double(regexp(w, '[0-9]*', 'match'));
                    systemRAM = stats(1)*1024;
                end
                %check if there is a Matlab pool
                pool = gcp('nocreate');
                if(~isempty(pool))
                    nWorkers = pool.NumWorkers;
                else
                    nWorkers = 0;
                end
                %minimum cache size is 256 MB
                maxSysCacheSz = max(256e6,(systemRAM - 1e9 - nWorkers*0.5e9) / 2); %substract 1 GB for Matlab, 0,5 GB per worker, allow half of the remainder as max cache
            end
            out = maxSysCacheSz;
        end

        function MatlabPoolIdleFcn()
            %function to keep matlab pool from timing out
            if(~isempty(gcp('nocreate')))
                parfor i = 1:10
                    y(i) = sin(i);
                end
            end
        end

        function openFLIMXUserGuide()
            %try to open the FLIMX user guide (pdf file)
            myDir = fullfile(FLIMX.getWorkingDir(),'doc','FLIMX_User_Guide.pdf');
            try
                open(myDir);
            catch ME
                %todo: message user or do something else if pdf is not found/can't be opened
                try
                    %try webbrowser
                    web(myDir,'-browser');
                catch ME2
                end
            end
        end

        function openFLIMXWebSite()
            %try to open www.flimx.de in system webbrower
            status = web('www.flimx.de','-browser');
            if(status ~= 0)
                %failed, try Matlab webbrowser
                web('www.flimx.de');
            end
        end

        function out = now()
            %get current time
            try
                out = datenummx(clock);  %fast
            catch
                out = now;  %slower
            end
        end

        function out = getLicenseInfo()
            %return license text
            [Y, ~, ~, ~, ~, ~] = datevec(now);
            if(Y > 2014)
                dStr = sprintf('-%d',Y);
            else
                dStr = '';
            end
            out = {sprintf('Copyright (c) 2014%s, authors of FLIMX. All rights reserved.',dStr);
                char(13);
                'Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:'
                char(13);
                '   * Redistributions of source code must retain the above copyright';
                '     notice, this list of conditions and the following disclaimer.';
                '   * Redistributions in binary form must reproduce the above';
                '     copyright notice, this list of conditions and the following';
                '     disclaimer in the documentation and/or other materials provided';
                '     with the distribution';
                '   * Neither the names of the FLIMX authors nor the names of its';
                '     names of its contributors may be used to endorse or promote';
                '     products derived from this software without specific prior';
                '     written permission.';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.';};
        end

        function out = getAcknowledgementInfo()
            %return acknowledgement text
            out = {
                'This software uses ''Scalar function-based filtering'' by Damien Garcia from http://www.biomecardio.com/matlab/sffilt.html';

                newline;
                'This software uses ''Fast and robust smoothing of one-dimensional and multidimensional data'' by Damien Garcia from http://www.biomecardio.com/matlab/smoothn.html';

                newline;
                'This software uses ''qinterp1'' by Nathaniel Brahms from http://www.mathworks.com/matlabcentral/fileexchange/10286-fast-interpolation';

                newline;
                'This software uses ''fminsearchbnd new'' by Ken Purchase from http://www.mathworks.com/matlabcentral/fileexchange/17804-fminsearchbnd-new';

                newline;
                'This software uses ''Fast smoothing function'' by T. C. O''Haver from http://www.mathworks.com/matlabcentral/fileexchange/19998-fast-smoothing-function, which is covered by the following license:';
                char(13);
                'Copyright (c) 2009, Tom O''Haver All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without';
                'modification, are permitted provided that the following conditions are';
                'met:';
                char(13);
                '* Redistributions of source code must retain the above copyright';
                '  notice, this list of conditions and the following disclaimer.';
                '* Redistributions in binary form must reproduce the above copyright';
                '  notice, this list of conditions and the following disclaimer in';
                '  the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''Recursive directory listing'' by Gus Brown from http://www.mathworks.com/matlabcentral/fileexchange/19550-recursive-directory-listing, which is covered by the following license:';
                'Copyright (c) 2009, Gus Brown';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without ';
                'modification, are permitted provided that the following conditions are ';
                'met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright ';
                '      notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright ';
                '      notice, this list of conditions and the following disclaimer in ';
                '      the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" ';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE ';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE ';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR ';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF ';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS ';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN ';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE ';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''CATSTRUCT'' by Jos van der Geest from http://www.mathworks.com/matlabcentral/fileexchange/7842-catstruct, which is covered by the following license:';
                'Copyright (c) 2009, Jos van der Geest';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without ';
                'modification, are permitted provided that the following conditions are ';
                'met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright ';
                '      notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright ';
                '      notice, this list of conditions and the following disclaimer in ';
                '      the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" ';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE ';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE ';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR ';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF ';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS ';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN ';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE ';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''struct2ini'' by Dirk Lohse from http://www.mathworks.com/matlabcentral/fileexchange/22079-struct2ini, which is covered by the following license:';
                'Copyright (c) 2009, Dirk Lohse';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without ';
                'modification, are permitted provided that the following conditions are ';
                'met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright ';
                '      notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright ';
                '      notice, this list of conditions and the following disclaimer in ';
                '      the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" ';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE ';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE ';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR ';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF ';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS ';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN ';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE ';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''ini2struct'' by Andriy Nych from http://www.mathworks.com/matlabcentral/fileexchange/17177-ini2struct, which is covered by the following license:';
                'Copyright (c) 2008, Andriy Nych';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without ';
                'modification, are permitted provided that the following conditions are ';
                'met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright ';
                '      notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright ';
                '      notice, this list of conditions and the following disclaimer in ';
                '      the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" ';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE ';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE ';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR ';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF ';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS ';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN ';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE ';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''Multicore - Parallel processing on multiple cores'' by Markus Buehren from http://www.mathworks.com/matlabcentral/fileexchange/13775-multicore-parallel-processing-on-multiple-cores, which is covered by the following license:';
                'Copyright (c) 2007, Markus Buehren';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without';
                'modification, are permitted provided that the following conditions are';
                'met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright';
                '      notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright';
                '      notice, this list of conditions and the following disclaimer in';
                '      the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''Differential Evolution'' by Markus Buehren from http://www.mathworks.com/matlabcentral/fileexchange/18593-differential-evolution, which is covered by the following license:';
                'Copyright (c) 2008, Markus Buehren';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without';
                'modification, are permitted provided that the following conditions are';
                'met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright';
                '      notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright';
                '      notice, this list of conditions and the following disclaimer in';
                '      the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''Another Particle Swarm Toolbox'' by Sam Chen from http://www.mathworks.com/matlabcentral/fileexchange/25986-another-particle-swarm-toolbox, which is covered by the following license:';
                'Copyright (c) 2009, Sam Chen';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.',

                newline;
                'This software uses ''settings dialog'' by Rody Oldenhuis from http://www.mathworks.com/matlabcentral/fileexchange/26312-settings-dialog, which is covered by the following license:';
                'Copyright (c) 2010, Rody Oldenhuis';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without';
                'modification, are permitted provided that the following conditions are ';
                'met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright ';
                '      notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright ';
                '      notice, this list of conditions and the following disclaimer in ';
                '      the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" ';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE ';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE ';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR ';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF ';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS ';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN ';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE ';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''ROC curve'' by Giuseppe Cardillo from http://www.mathworks.com/matlabcentral/fileexchange/19950-roc-curve, which is covered by the following license:';
                'Copyright (c) 2014, Giuseppe Cardillo';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without';
                'modification, are permitted provided that the following conditions are';
                'met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright';
                '      notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright';
                '      notice, this list of conditions and the following disclaimer in';
                '      the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''Clinical Test Performance'' by Giuseppe Cardillo from http://www.mathworks.com/matlabcentral/fileexchange/12705-clinical-test-performance, which is covered by the following license:';
                'Copyright (c) 2006, Giuseppe Cardillo';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without';
                'modification, are permitted provided that the following conditions are';
                'met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright';
                '      notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright';
                '      notice, this list of conditions and the following disclaimer in';
                '      the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''rotate xtick labels of an axes'' by Brian Katz from http://www.mathworks.com/matlabcentral/fileexchange/3486-xticklabel-rotate, which is covered by the following license:';
                'Copyright (c) 2003, Brian Katz';
                'Copyright (c) 2009, The MathWorks, Inc.';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without ';
                'modification, are permitted provided that the following conditions are ';
                'met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright ';
                '      notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright ';
                '      notice, this list of conditions and the following disclaimer in ';
                '      the documentation and/or other materials provided with the distribution';
                '    * Neither the name of the The MathWorks, Inc. nor the names ';
                '      of its contributors may be used to endorse or promote products derived ';
                '      from this software without specific prior written permission.';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" ';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE ';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE ';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR ';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF ';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS ';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN ';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE ';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''findjobj'' by Yair Altman from http://www.mathworks.com/matlabcentral/fileexchange/14317-findjobj-find-java-handles-of-matlab-graphic-objects, which is covered by the following license:';
                'Copyright (c) 2014, Yair Altman';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without ';
                'modification, are permitted provided that the following conditions are ';
                'met:';
                char(13);
                '    * Redistributions of source code must retain the above copyright ';
                '      notice, this list of conditions and the following disclaimer.';
                '    * Redistributions in binary form must reproduce the above copyright ';
                '      notice, this list of conditions and the following disclaimer in ';
                '      the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses the color maps ''Magma'', ''Inferno'', ''Plasma'', ''Virirdis'' by Nathaniel Smith & Stefan van der Walt from https://bids.github.io/colormap, which is covered by the following license:';
                'CC0 1.0 Universal';
                'No Copyright';
                char(13);
                'mpl-colormaps by Nathaniel Smith & Stefan van der Walt' ;
                'To the extent possible under law, the persons who associated CC0 with';
                'mpl-colormaps have waived all copyright and related or neighboring rights';
                'to mpl-colormaps.';
                'You should have received a copy of the CC0 legalcode along with this';
                'work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.';

                newline;
                'This software uses ''DirSize'' by Richard Moore from https://de.mathworks.com/matlabcentral/fileexchange/41300-dirsize, which is covered by the following license:';
                'Copyright (c) 2013, Richard Moore';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without';
                'modification, are permitted provided that the following conditions are';
                'met:';
                char(13);
                '   * Redistributions of source code must retain the above copyright';
                '     notice, this list of conditions and the following disclaimer.';
                '   * Redistributions in binary form must reproduce the above copyright';
                '     notice, this list of conditions and the following disclaimer in';
                '     the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses parts of Coye, Tyler (2015). A Novel Retinal Blood Vessel Segmentation Algorithm for Fundus Images (http://www.mathworks.com/matlabcentral/fileexchange/50839), MATLAB Central File Exchange.[retrieved 20th August 2017]';
                'Copyright (c) 2017, Tyler Coye';
                'Copyright (c) 2015, Matt Smith';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without';
                'modification, are permitted provided that the following conditions are';
                'met:';
                char(13);
                '* Redistributions of source code must retain the above copyright';
                'notice, this list of conditions and the following disclaimer.';
                '* Redistributions in binary form must reproduce the above copyright';
                'notice, this list of conditions and the following disclaimer in';
                'the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''disk_free'' by Igor from https://www.mathworks.com/matlabcentral/fileexchange/41904-disk-usage, which is covered by the following license:';
                'Copyright (c) 2013, Igor';
                'All rights reserved.';
                char(13);
                'Redistribution and use in source and binary forms, with or without';
                'modification, are permitted provided that the following conditions are met:';
                char(13);
                '* Redistributions of source code must retain the above copyright';
                'notice, this list of conditions and the following disclaimer.';
                '* Redistributions in binary form must reproduce the above copyright';
                'notice, this list of conditions and the following disclaimer in';
                'the documentation and/or other materials provided with the distribution';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"';
                'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE';
                'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE';
                'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE';
                'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR';
                'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF';
                'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS';
                'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN';
                'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)';
                'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE';
                'POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses the color maps ''Cividis'', ''Twilight'' and ''TwilightShifted'' from https://github.com/opencv, which is covered by the following license:';
                'Copyright (C) 2000-2019, Intel Corporation, all rights reserved.';
                'Copyright (C) 2009-2011, Willow Garage Inc., all rights reserved.';
                'Copyright (C) 2009-2016, NVIDIA Corporation, all rights reserved.';
                'Copyright (C) 2010-2013, Advanced Micro Devices, Inc., all rights reserved.';
                'Copyright (C) 2015-2016, OpenCV Foundation, all rights reserved.';
                'Copyright (C) 2015-2016, Itseez Inc., all rights reserved.';
                'Third party copyrights are property of their respective owners.';
                char(13);
                'Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:';
                char(13);
                '* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.';
                '* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.';
                '* Neither the names of the copyright holders nor the names of the contributors may be used to endorse or promote products derived from this software without specific prior written permission.';
                char(13);
                'This software is provided by the copyright holders and contributors �as is� and any express or implied warranties, including, but not limited to, the implied warranties of merchantability and fitness for a particular purpose are disclaimed. In no event shall copyright holders or contributors be liable for any direct, indirect, incidental, special, exemplary, or consequential damages (including, but not limited to, procurement of substitute goods or services; loss of use, data, or profits; or business interruption) however caused and on any theory of liability, whether in contract, strict liability, or tort (including negligence or otherwise) arising in any way out of the use of this software, even if advised of the possibility of such damage.';

                newline;
                'This software uses ''logging4matlab'' by Dominique Orban from https://github.com/optimizers/logging4matlab, which is covered by the following license:';
                'MIT License'
                'Copyright (c) 2016 optimizers';
                char(13);
                'Permission is hereby granted, free of charge, to any person obtaining a copy';
                'of this software and associated documentation files (the "Software"), to deal';
                'in the Software without restriction, including without limitation the rights';
                'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell';
                'copies of the Software, and to permit persons to whom the Software is';
                'furnished to do so, subject to the following conditions:';
                char(13);
                'The above copyright notice and this permission notice shall be included in all';
                'copies or substantial portions of the Software.';
                char(13);
                'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR';
                'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,';
                'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE';
                'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER';
                'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,';
                'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE';
                'SOFTWARE.';

                newline;
                'This software uses ''MATLAB Color Tools'' by Steve Eddins from https://github.com/mathworks/matlab-color-tools, which is covered by the following license:';
                'Copyright (c) 2018-2019, The MathWorks, Inc.';
                char(13);
                'Redistribution and use in source and binary forms, with or without modification,';
                'are permitted provided that the following conditions are met:';
                char(13);
                '1. Redistributions of source code must retain the above copyright notice, this';
                'list of conditions and the following disclaimer.';
                char(13);
                '2. Redistributions in binary form must reproduce the above copyright notice,';
                'this list of conditions and the following disclaimer in the documentation and/or';
                'other materials provided with the distribution.';
                char(13);
                '3. In all cases, the software is, and all modifications and derivatives of the';
                'software shall be, licensed to you solely for use in conjunction with MathWorks';
                'products and service offerings.';
                char(13);
                'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND';
                'ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED';
                'WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE';
                'DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR';
                'ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES';
                '(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;';
                'LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON';
                'ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT';
                '(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS';
                'SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.';

                newline;
                'This software uses ''Violinplot-Matlab'' by Bastian Bechtold from https://github.com/bastibe/Violinplot-Matlab, which is released under the terms of the BSD 3-clause license.';
                char(13);
                
                newline;
                'This software uses ''MEXlibCZI'' by ptahmose from https://https://github.com/ptahmose/MEXlibCZI, which is covered by the following license:';
                'GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007';
                char(13);
                };
        end

    end %methods(Static)
end
