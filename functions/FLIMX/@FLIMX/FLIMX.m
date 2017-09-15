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
        fdt = [];        %FDTree object, our datastorage  
        irfMgr = [];        %object to handle IRF access        
        paramMgr = [];      %parameter objects
        curSubject = [];    %current subject   
    end
    
    properties(GetAccess = protected, SetAccess = private)
        FLIMFitObj = [];    %approximation object
        sDDMgrObj = [];     %only temporary: manage synthetic datasets        
        batchJobMgrObj = [];   %batch job manager
        %GUIs
        FLIMFitGUIObj = []; %visualization of approximation        
        FLIMVisGUIObj = []; %extended visualization and statistics
        studyMgrGUIObj = [];%manager for subject studies
        irfMgrGUIObj = [];  %GUI to handle IRF access
        batchJobMgrGUIObj = [];%batch job manager GUI
        importMeasurementGUIObj = [];  %measurement import wizard
        importResultGUIObj = [];  %result import wizard
        matlabPoolTimer = [];
        splashScreenGUIObj = [];
    end
    
    properties (Dependent = true)
        configPath = '';
        %objects
        FLIMFit = [];    %approximation object
        sDDMgr = [];     %only temporary: manage synthetic datasets        
        batchJobMgr = [];   %batch job manager
        
        FLIMFitGUI = [];     %visualization of approximation        
        FLIMVisGUI = []; %extended visualization and statistics
        studyMgrGUI = [];%manager for subject studies
        irfMgrGUI = [];  %GUI to handle IRF access
        batchJobMgrGUI = [];%batch job manager GUI
        importGUI = [];  %import wizard
        importResultGUI = [];  %result import wizard
        splashScreenGUI = []; %splash screen
    end
    
    methods
        function this = FLIMX()
            %constructor
            this.splashScreenGUIObj = FLIMXSplashScreen();
            this.updateSplashScreenProgressLong(0.01,'Loading IRFs...');
            %parameters from ini file
            warning('off','parallel:gpu:DeviceCapabiity');
            %make lower level objects
            this.paramMgr = FLIMXParamMgr(this,FLIMX.getVersionInfo());            
            this.irfMgr = IRFMgr(this,fullfile(FLIMX.getWorkingDir(),'data'));
            this.updateSplashScreenProgressLong(0.3,'Building data tree structure...');
            this.fdt = FDTree(this,FLIMX.getWorkingDir()); %replace with path from config?!
            this.updateSplashScreenProgressShort(0,'');
            fp = this.paramMgr.getParamSection('filtering');
            if(fp.ifilter)
                alg = fp.ifilter_type;
                params = fp.ifilter_size;
            else
                alg = 0;
                params = 0;
            end
            this.fdt.setDataSmoothFilter(alg,params);
            %set window size
            if(this.paramMgr.generalParams.autoWindowSize)
                this.paramMgr.generalParams.windowSize = FLIMX.getAutoWindowSize();
            end
            %load a subject
            this.updateSplashScreenProgressLong(0.5,'Loading first subject...');
            subs = this.fdt.getSubjectsNames('Default',FDTree.defaultConditionName());
            if(isempty(subs))
                %todo: generate a dummy subject with simulated data
                this.setCurrentSubject('Default',FDTree.defaultConditionName(),'');
            else
                this.setCurrentSubject('Default',FDTree.defaultConditionName(),subs{1});
            end
            this.updateSplashScreenProgressLong(0.7,'Opening MATLAB pool...');
            this.openMatlabPool();
            this.updateSplashScreenProgressShort(0,'');
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
                    this.splashScreenGUIObj.updateProgressShort(0.5,sprintf('MATLAB pool workers can be disabled in Settings -> Computation'));
                end
                try
                    p = parpool('local',feature('numCores'));
                    this.splashScreenGUIObj.updateProgressShort(1,'Trying to open pool of MATLAB workers - done');
                    %p.IdleTimeout = 0;
                catch ME
                    if(ishandle(this.splashScreenGUIObj))
                        this.splashScreenGUIObj.updateProgressShort(1,'Trying to open pool of Matlab workers - failed');
                    end
                    warning('FLIMX:openMatlabPool','Could not open Matlab pool for parallel computations: %s',ME.message);
                end
            end
            if(~isempty(p))
                this.matlabPoolTimer = timer('ExecutionMode','fixedRate','Period',p.IdleTimeout/2*60,'TimerFcn','FLIMX.MatlabPoolIdleFcn','Tag','FLIMXMatlabPoolTimer');
                start(this.matlabPoolTimer);
            end
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
            if(~isempty(p))
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
            if(forceFlag || (~this.FLIMFitGUI.isOpenVisWnd() && ~this.FLIMVisGUI.isOpenVisWnd()))
                %do some cleanup
                studies = this.fdt.getStudyNames();
                askUser = true;
                for i = 1:length(studies)
                    if(~isempty(studies{i}) && any(this.fdt.checkStudyDirtyFlag(studies{i})))
                        if(askUser)
                            choice = questdlg(sprintf('Save changes to study ''%s''?',studies{i}),'Save study?','Yes','All','No','Yes');
                            switch choice
                                case 'Yes'
                                    this.fdt.saveStudy(studies{i});
                                case 'All'
                                    askUser = false;
                                    this.fdt.saveStudy(studies{i});
%                                 case 'No'
%                                     %load unmodified study and check files
%                                     this.fdt.loadStudy(studies{i});
                            end
                        else
                            %always save changes
                            this.fdt.saveStudy(studies{i});
                        end
                        this.fdt.checkStudyFiles(studies{i});
                    end
                end
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
                if(~isempty(this.studyMgrGUIObj))
                    this.studyMgrGUIObj.menuExit_Callback();
                end
                if(~isempty(this.batchJobMgrGUIObj))
                    this.batchJobMgrGUIObj.menuExit_Callback();
                end
                if(~isempty(this.irfMgrGUIObj))
                    this.irfMgrGUIObj.menuExit_Callback();
                end
                if(~isempty(this.irfMgrGUIObj))
                    this.irfMgrGUIObj.menuExit_Callback();
                end
                if(~isempty(this.matlabPoolTimer))
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
        
        function saveCurResultInFDT(this)
            %save dirty channels of current result in FDTree
            for ch = find(this.curSubject.resultIsDirty)
                this.curSubject.updateSubjectChannel(ch,'result');
                this.fdt.saveStudy(this.curSubject.getStudyName());
            end
        end        
        
        function success = setCurrentSubject(this,study,view,subject)
            %set the current subject
            success = true;            
            studyPos = find(strcmp(study,this.fdt.getStudyNames()),1);
            if(isempty(studyPos))
                success = false;
                return
            end
            if(isempty(subject))
                this.curSubject = this.fdt.getSubject4Import(study,'example_subject');
            else
                subjectPos = find(strcmp(subject,this.fdt.getSubjectsNames(study,view)),1);
                if(~isempty(subjectPos) && isempty(this.curSubject) || (~strcmp(this.curSubject.getStudyName(),study) || ~strcmp(this.curSubject.getDatasetName(),subject)))
                    %save old result
                    if(~isempty(this.curSubject) && any(this.curSubject.resultIsDirty))
                        button = questdlg(sprintf('Approximation result was changed. Do you want to save the changes?'),'Approximation Result Changed','Yes','No','Yes');
                        switch button
                            case 'Yes'
                                this.saveCurResultInFDT();
                        end
                    end
                    this.curSubject = this.fdt.getSubject4Approx(study,subject);
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
                    [tmp,yPos] = max(img,[],1);
                    [~,xPos] = max(tmp);
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
            this.FLIMFitGUI.updateProgressShort(x,text);
        end
        
        function updateSplashScreenProgressShort(this,x,text)
            %set short progress in splash screen to new value
            if(~isempty(this.splashScreenGUIObj))
                this.splashScreenGUIObj.updateProgressShort(x,text);
            end
        end
        
        function updateSplashScreenProgressLong(this,x,text)
            %set short progress in splash screen to new value
            if(~isempty(this.splashScreenGUIObj))
                this.splashScreenGUIObj.updateProgressLong(x,text);
            end
        end        
        
    end %methods
    
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
        
        function [mapNames, iconPaths] = getColormaps()
            %get names and path to images of color maps            
            persistent cmNames cmPaths
            if(isempty(cmPaths))
                cmNames = {'Autumn','Bone','Colorcube','Cool','Copper','Flag','Gray','Hot','Hsv','Inferno','Jet','Lines','Magma','Parula','Pink','Plasma','Prism','Spring','Summer','Viridis','White','Winter'};                
                cmPaths = strcat([FLIMX.getWorkingDir() filesep 'data' filesep 'colormap_'], cmNames', '.png');
                for i = length(cmPaths):-1:1
                    if(~exist(cmPaths{i},'file'))
                        %no color map icon found -> generate it
                        map = zeros(1,256,3);
                        eval(sprintf('map(1,:,:) = %s(256);',lower(cmNames{i})));
                        if(any(map(:)))
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
            out.config_revision = 262;
            out.client_revision = 378;
            out.core_revision = 364;
            out.results_revision = 256;
            out.measurement_revision = 204;
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
        
        function MatlabPoolIdleFcn()
            %function to keep matlab pool from timing out
            if(~isempty(gcp('nocreate')))
                parfor i = 1:10
                    y(i) = sin(i);
                end
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
                
                char(10);
                'This software uses ''Fast and robust smoothing of one-dimensional and multidimensional data'' by Damien Garcia from http://www.biomecardio.com/matlab/smoothn.html';
                
                char(10);
                'This software uses ''qinterp1'' by Nathaniel Brahms from http://www.mathworks.com/matlabcentral/fileexchange/10286-fast-interpolation';
                
                char(10);
                'This software uses ''fminsearchbnd new'' by Ken Purchase from http://www.mathworks.com/matlabcentral/fileexchange/17804-fminsearchbnd-new';
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                
                char(10);
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
                                
                char(10);
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
                
                char(10);
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
                
                };
        end
        
    end %methods(Static)
end

