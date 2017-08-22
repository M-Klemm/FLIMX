classdef FLIMXParamMgr < paramMgr
    %=============================================================================================================
    %
    % @file     FLIMXParamMgr.m
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
    % @brief    A class to manage parameters for FLIMX, with ini-file access
    %
    properties(GetAccess = private, SetAccess = private)
        FLIMXObj = [];        
        fileName = '';
    end
    
    properties (Dependent = true)
        fdt = [];
        FLIMFitGUI = [];
        FLIMVisGUIObj = [];
    end
    
    methods
        function this = FLIMXParamMgr(hFLIMX,about)
            %constructor            
            this = this@paramMgr(about);
            this.FLIMXObj = hFLIMX;
            this.setFileName(hFLIMX.configPath);
            this.readConfig();
        end
        
        %% input methods
        function setFileName(this,fn)
            %set filename of config file
            this.fileName = fn;
        end
                
        function readConfig(this)
            %read config information from disk
            if(~isempty(this.fileName))
                ini = paramMgr.ini2struct(this.fileName);
%                 if(isempty(ini))
%                     uiwait(warndlg('config.ini empty or not found! Using defaults instead.','config.ini not found!','modal'));
%                 end
            else
                ini = [];
            end
            ini_isdirty = false;
            try
                if(ini.about.config_revision < 130)
                    ini = rmfield(ini,{'basic_fit'});
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 138)
                    if(isfield(ini,'basic_fit'))
                        ini.basic_fit = rmfield(ini.basic_fit,{'approxTech'});
                    end
                    ini = rmfield(ini,{'bounds_s_exp'});
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 139)
                    ini.init_fit.errorMode  = min(ini.init_fit.errorMode,5);
                    ini.pixel_fit.errorMode  = min(ini.pixel_fit.errorMode,5);
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 140)
                    if(isfield(ini,'basic_fit'))
                        if(isfield(ini.basic_fit,'useGPU'))
                            ini.computation.useGPU  = ini.basic_fit.useGPU;
                            ini.basic_fit = rmfield(ini.basic_fit,{'useGPU'});
                        end
                    end
                    ini_isdirty = true;
                end                
                
                if(ini.about.config_revision < 200)
                    %try to delete old config files
                    fn = fullfile(fileparts(this.fileName),'FitConfig.ini');
                    if(exist(fn,'file'))
                        delete(fn);
                    end
                    fn = fullfile(fileparts(this.fileName),'VisConfig.ini');
                    if(exist(fn,'file'))
                        delete(fn);
                    end
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 217)
                    ini.options_de.maxReInitCnt = 20;
                    if(isfield(ini,'bounds_2_exp'))
                        ini = rmfield(ini,{'bounds_2_exp'});
                    end
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 220)
                    if(isfield(ini,'pixel_fit'))
                        ini = rmfield(ini,{'pixel_fit'});
                    end
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 222)
                    if(isfield(ini,'bounds_3_exp'))
                        ini = rmfield(ini,{'bounds_3_exp'});
                    end
                    if(isfield(ini,'options_de'))
                        ini = rmfield(ini,{'options_de'});
                    end
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 223)
                    if(isfield(ini,'bounds_offset'))
                        ini = rmfield(ini,{'bounds_offset'});
                    end
                    ini_isdirty = true;
                end
                
                if(ini.about.client_revision < 241)
                    if(isfield(ini,'options_de'))
                        ini = rmfield(ini,{'options_de'});
                    end
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 230)
                    if(isfield(ini,'init_fit'))
                        ini = rmfield(ini,{'init_fit'});
                    end
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 238)
                    if(isfield(ini,'basic_fit') && isfield(ini.basic_fit,'fixHShiftGridSize'))
                        ini.init_fit.gridSize = ini.basic_fit.fixHShiftGridSize;
                        ini.basic_fit = rmfield(ini.basic_fit,{'fixHShiftGridSize'});
                    end
                    if(isfield(ini,'basic_fit') && isfield(ini.basic_fit,'initGridPhotons'))
                        ini.init_fit.gridPhotons = ini.basic_fit.initGridPhotons;
                        ini.basic_fit = rmfield(ini.basic_fit,{'initGridPhotons'});
                    end
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 240)
                    if(isfield(ini,'folders') && isfield(ini.folders,'mcShare'))
                        ini.computation.mcShare = ini.folders.mcShare;
                        ini = rmfield(ini,{'folders'});
                    end
                    if(isfield(ini,'init_fit') && isfield(ini.init_fit,'pixelJitter'))
                        ini.init_fit = rmfield(ini.init_fit,{'pixelJitter'});
                    end
                    if(isfield(ini,'pixel_fit'))
                        if(isfield(ini.pixel_fit,'pixelJitter'))
                            ini.pixel_fit = rmfield(ini.pixel_fit,{'pixelJitter'});
                        end
                        if(isfield(ini.pixel_fit,'outlierStage'))
                            ini.pixel_fit = rmfield(ini.pixel_fit,{'outlierStage'});
                        end
                    end                    
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 244)
                    ini.basic_fit.curIRFID = 'Ilmenau_01.09.2014';
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 245)
                    if(isfield(ini,'fluo_decay_fit_gui') && isfield(ini.fluo_decay_fit_gui,'cmType'))
                        ini.general.cmType = ini.fluo_decay_fit_gui.cmType;
                        ini.fluo_decay_fit_gui = rmfield(ini.fluo_decay_fit_gui,{'cmType'});
                    end
                    if(isfield(ini,'fluo_decay_fit_gui') && isfield(ini.fluo_decay_fit_gui,'cmInvert'))
                        ini.general.cmInvert = ini.fluo_decay_fit_gui.cmInvert;
                        ini.fluo_decay_fit_gui = rmfield(ini.fluo_decay_fit_gui,{'cmInvert'});
                    end
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 246)
                    if(isfield(ini,'basic_fit') && isfield(ini.basic_fit,'fittedChiWeighting') && ini.basic_fit.fittedChiWeighting == 1)
                        ini.basic_fit.chiWeightingMode = 3;
                    end
                    if(isfield(ini,'basic_fit') && isfield(ini.basic_fit,'errorMode'))
                        ini.basic_fit.errorMode = max(1,ini.basic_fit.errorMode-1);
                    end
                    ini_isdirty = true;
                end
                
                if(ini.about.config_revision < 250)
                    if(isfield(ini,'statistics')) %add a second channel to statistics parameters
                        fn = fieldnames(ini.statistics);
                        for i=1:length(fn)
                            ini.statistics.(fn{i}) = repmat(ini.statistics.(fn{i}),1,2);
                        end
                    end
                end
                
                if(ini.about.client_revision < 326)
                    if(isfield(ini,'basic_fit'))
                        if(isfield(ini.basic_fit,'risingEdgeErrorMargin') && ini.basic_fit.risingEdgeErrorMargin < 4)
                            ini.basic_fit.risingEdgeErrorMargin = 4;
                            ini_isdirty = true;
                        end
                    end
                end
                
                if(ini.about.config_revision < 255)
                    if(isfield(ini,'basic_fit')) %rename errorMode field
                        if(isfield(ini.basic_fit,'errorMode'))
                            ini.basic_fit.figureOfMeritModifier = ini.basic_fit.errorMode;
                            ini_isdirty = true;
                        end
                    end
                end
                if(ini_isdirty || ini.about.client_revision < this.about.client_revision || ini.about.config_revision < this.about.config_revision)
                    %generic version mismatch
                    ini = rmfield(ini,{'about'});
                    ini_isdirty = true;
                end
            catch
                %something went wrong - get defaults
                ini = this.getDefaults();
                ini_isdirty = 1;
            end            
            %save updated ini
            if(ini_isdirty && ~isempty(this.fileName))
                %check if dir for config exists - if not: create it
                idx = strfind(this.fileName,filesep);
                pathstr = this.fileName(1:idx(end)-1);
                if(~isdir(pathstr))
                    [status, message, ~] = mkdir(pathstr);
                    if(~status)
                        error('FLIMX:FLIMXParamMgr:readConfig','Could not create config folder: %s\n%s',pathstr,message);
                    end
                end
                paramMgr.struct2ini(this.fileName,checkStructConsistency(ini,this.getDefaults()));
                disp('Config update was successful.');
            end
            %to be sure everything is in order
            ini = checkStructConsistency(ini,this.getDefaults());
            %special treatment
            if(isfield(ini,'basic_fit'))
                for i=1:16                    
                    tmp = {''};
                    str = sprintf('constMaskSaveStrCh%d',i);
                    if(~isempty(ini.basic_fit.(str)))
                        tmp = textscan(ini.basic_fit.(str),'%s','delimiter','|','MultipleDelimsAsOne',1);
                    end
                    ini.basic_fit.(str) = [tmp{:}];
                end
                tmp = {''};
                if(~isempty(ini.basic_fit.globalFitMaskSaveStr))
                    tmp = textscan(ini.basic_fit.globalFitMaskSaveStr,'%s','delimiter','|','MultipleDelimsAsOne',1);
                end
                ini.basic_fit.globalFitMaskSaveStr = [tmp{:}];                
                %convert init fix targets
                tmp = {''};
                if(~isempty(ini.basic_fit.fix2InitTargets))
                    tmp = textscan(ini.basic_fit.fix2InitTargets,'%s','delimiter','|','MultipleDelimsAsOne',1);
                end                
                ini.basic_fit.fix2InitTargets = [tmp{:}];                
            end  
            if(isfield(ini,'cleanup_fit'))
                tmp = {''};
                if(~isempty(ini.cleanup_fit.target))
                    tmp = textscan(ini.cleanup_fit.target,'%s','delimiter','|','MultipleDelimsAsOne',1);
                end
                ini.cleanup_fit.target = [tmp{:}];
                tmp = {''};
            end
            if(isfield(ini,'general'))
                tmp = {''};
                if(~isempty(ini.general.cmType))
                    tmp = textscan(ini.general.cmType,'%s','delimiter','|','MultipleDelimsAsOne',1);
                end                
                ini.general.cmType = tmp{1}{:};
                tmp = {''};
                if(~isempty(ini.general.cmIntensityType))
                    tmp = textscan(ini.general.cmIntensityType,'%s','delimiter','|','MultipleDelimsAsOne',1);
                end                
                ini.general.cmIntensityType = tmp{1}{:};
            end
%             if(isfield(ini,'flimvis_gui'))
%                 tmp = {''};
%                 if(~isempty(ini.flimvis_gui.cmType))
%                     tmp = textscan(ini.flimvis_gui.cmType,'%s','delimiter','|','MultipleDelimsAsOne',1);
%                 end                
%                 ini.flimvis_gui.cmType = tmp{1}{:};
%             end
            this.data = ini;
        end
        
        function goOn = setParamSection(this,sStr,new,resetResults)
            %set a parameter section to new values, save to disk if writeFlag == true
            if(isempty(this.data))
                %try to read the config file
                this.readConfig()
            end
            if(nargin < 4)
                resetResults = true;
            end
            writeFlag = true;
            goOn = setParamSection@paramMgr(this,sStr,new,resetResults);
            if(writeFlag && goOn)
                this.writeConfig();
            end
        end
            
        
        %% output methods
        function out = getFileName(this)
            %return config file name
            out = this.fileName;
        end
        
        function out = get.fdt(this)
            %get handle to fdt
            out = this.FLIMXObj.fdt;
        end        
        
        function out = get.FLIMFitGUI(this)
            %get handle to fit gui
            out = this.FLIMXObj.FLIMFitGUI;
        end                
        
        function out = get.FLIMVisGUIObj(this)
            %set handle to FLIMVis gui
            out = this.FLIMXObj.FLIMVisGUI;
        end
        
%         function out = getFluoFileHandle(this)
%             %return handle of the fluo file I'm connected to
%             out = this.myFluoFile;
%         end
        
        function out = getParamSection(this,sStr)
            %return one or multiple parameter sections
            if(isempty(this.data))
                %try to read the config file
                this.readConfig()
            end
            out = getParamSection@paramMgr(this,sStr);
        end
                
        function writeConfig(this)
            %write back to disk
            if(isempty(this.data))
                return
            end
            ini = this.data;
            ini.about = this.about;
            %convert constants mask
            for j=1:16
                str = '';
                str2 = sprintf('constMaskSaveStrCh%d',j);
                for i = 1:length(ini.basic_fit.(str2))
                    str = strcat(str,ini.basic_fit.(str2){i},'|');
                end
                ini.basic_fit.(str2) = str;
            end
            %convert init fix targets
            str = '';
            for i = 1:length(ini.basic_fit.fix2InitTargets)
                str = strcat(str,ini.basic_fit.fix2InitTargets{i},'|');
            end
            ini.basic_fit.fix2InitTargets = str;
            %cleanup fit targets
            str = '';
            for i = 1:length(ini.cleanup_fit.target)
                str = strcat(str,ini.cleanup_fit.target{i},'|');
            end
            ini.cleanup_fit.target = str;
            %convert global fit mask
            str = '';
            for i = 1:length(ini.basic_fit.globalFitMaskSaveStr)
                str = strcat(str,ini.basic_fit.globalFitMaskSaveStr{i},'|');
            end
            ini.basic_fit.globalFitMaskSaveStr = str;
            %convert color map                       
            ini.general.cmType = strcat(ini.general.cmType,'|');
            ini.general.cmIntensityType = strcat(ini.general.cmIntensityType,'|');
            FLIMXParamMgr.struct2ini(this.fileName,ini);
        end
    end
    
    methods(Access = protected)
        %internal methods
        function goOn = setSection(this,sStr,new,resetResults)
            %single parameter struct
            goOn = true;
            %update new sections
            if(any(strcmp(sStr,fieldnames(this.data))))
                fields = intersect(fieldnames(new),fieldnames(this.data.(sStr)));
                tmp = this.data.(sStr);
                old = tmp;
                for j = 1:length(fields)
                    tmp.(fields{j}) = new.(fields{j});
                end
                this.data.(sStr) = tmp;
                %update other objects if necessary
                switch sStr
%                     case 'pre_processing'
%                         %possible binning change
%                         if(~isempty(this.myFluoFile))
%                             this.myFluoFile.clearROIData();
%                         end
%                     case 'basic_fit'
%                         this.volatileChannelParams{1}.cVec = [];
%                         this.volatileChannelParams{2}.cVec = [];
%                         this.updateNParams();
%                     case 'init_fit'
%                         if(~isempty(this.myFluoFile) && (isfield(new,'gridSize') && new.gridSize ~= old.gridSize || isfield(new,'gridPhotons') && new.gridPhotons ~= old.gridPhotons))
%                             this.myFluoFile.clearROIData();
%                         end
                    case 'filtering'
                        if(isfield(new,'ifilter') && new.ifilter)
                            alg = new.ifilter_type;
                            params = new.ifilter_size;
                        else
                            alg = 0;
                            params = 0;
                        end
                        if(~isempty(this.fdt))
                            this.fdt.setDataSmoothFilter(alg,params);
                        end
                    case 'general'
                        if(isfield(new,'autoWindowSize') && old.autoWindowSize ~= new.autoWindowSize && new.autoWindowSize == 1)                            
                            new.windowSize = FLIMX.getAutoWindowSize(); %just to make sure, should have been set already
                        end
                        if(isfield(new,'windowSize') && ~isempty(this.FLIMFitGUI) && this.FLIMFitGUI.isOpenVisWnd() && this.FLIMFitGUI.visHandles.mySize ~= new.windowSize)
                            button = questdlg(sprintf('Window size was changed. FLIMXFit needs to restart.\n\nAll unsaved data will be lost!\n\nDo you want to proceed?'),'Window size changed','Restart later','Restart now','Restart later');
                            switch button
                                case 'Restart now'
                                    if(ishandle(this.FLIMFitGUI.visHandles.FLIMXFitGUIFigure))
                                        delete(this.FLIMFitGUI.visHandles.FLIMXFitGUIFigure);
                                    end
                                    this.FLIMFitGUI.checkVisWnd();
                            end
                        end
                        if(isfield(new,'windowSize') && ~isempty(this.FLIMVisGUIObj) && this.FLIMVisGUIObj.isOpenVisWnd() && this.FLIMVisGUIObj.visHandles.mySize ~= new.windowSize)
                            button = questdlg(sprintf('Window size was changed. FLIMXVis needs to restart.\n\nAll unsaved data will be lost!\n\nDo you want to proceed?'),'Window size changed','Restart later','Restart now','Restart later');
                            switch button
                                case 'Restart now'
                                    if(ishandle(this.FLIMVisGUIObj.visHandles.FLIMXVisGUIFigure))
                                        delete(this.FLIMVisGUIObj.visHandles.FLIMXVisGUIFigure);
                                    end
                                    this.FLIMVisGUIObj.checkVisWnd();
                            end
                        end
                    case 'computation'
                        %                         %check GPU support
                        %                         warning('off','parallel:gpu:DeviceCapability');
                        %                         if(isfield(new,'useGPU') && new.useGPU && isempty(this.volatilePixelParams.compatibleGPUs) && isGpuAvailable())
                        %                             GPUList = [];
                        %                             for i = 1:gpuDeviceCount
                        %                                 info = gpuDevice(i);
                        %                                 if(info.DeviceSupported)
                        %                                     GPUList = [GPUList i];
                        %                                 end
                        %                             end
                        %                             this.volatilePixelParams.compatibleGPUs = GPUList;
                        %                         elseif(isfield(new,'useGPU') && ~new.useGPU)
                        %                             this.volatilePixelParams.compatibleGPUs = [];
                        %                         end
                        %                         warning('on','parallel:gpu:DeviceCapability');
                        if(~isempty(this.FLIMXObj) && new.useMatlabDistComp > 0 && isempty(gcp('nocreate')))
                            %open a pool
                            this.FLIMXObj.openMatlabPool();
                        elseif(~isempty(this.FLIMXObj) && new.useMatlabDistComp == 0 && ~isempty(gcp('nocreate')))
                            %close our pool
                            this.FLIMXObj.closeMatlabPool();                            
                        end
                end
            else
                goOn = false;
                warning('paramMgr:setSection','Parameter section %s not found in config file. The section has been ignored.',sStr);
            end
        end
        
    end
end