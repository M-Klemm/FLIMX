%opens FLIMX, a tool to approximate and analyze FLIM parameters
%(e.g. amplitude, lifetime) of measurements or simulations

if(isdeployed())
    %if deployed, allow only one instance
    %currently not needed as the database file lock should cover this
%     flimxRunning = false;
%     if(ispc())
%         try
%             p = System.Diagnostics.Process.GetProcessesByName('flimx');
%             if(length(p) > 1)
%                 flimxRunning = true;
%             end
%         end
%     else
%         try
%             [~,cmdout] = system('grep -f flimx');
%             p = textscan(cmdout,'%d');
%             if(length(p) > 1)
%                 flimxRunning = true;
%             end
%         end
%     end
%     clear p cmdout
%     if(flimxRunning)
%         uiwait(errordlg(sprintf('FLIMX is already running. Only one instance at a time is allowed.\nPlease use the other instance or close it before opening a new one.'),'FLIMX already open','modal'));
%         return
%     end
else
    %check Matlab version
    nr = version('-release');
    reqMajor = 2017;
    reqMinor = 'a';
    if(~(str2double(nr(1:4)) > reqMajor || str2double(nr(1:4)) == reqMajor && strcmp(nr(end),reqMinor)))
        uiwait(errordlg(sprintf('Your MATLAB version is R%s. This software requires MATLAB R%d%s or newer. Please update your MATLAB installation.',nr,reqMajor,reqMinor),'MATLAB version too old','modal'));
        return
    end
    clear nr;
end
%check for physical memory
if(ispc())
    [~,sys] = memory;
    if(sys.PhysicalMemory.Total < (2^31-100e6))
        uiwait(warndlg(sprintf('Your computer has only %dGB of RAM. 2GB are the minimal requirement for useful operation of this software. 4GB or more are recommended!',ceil(sys.PhysicalMemory.Total/2^30)),'Low amount of RAM','modal'));
    end
    clear sys
end
if(~isdeployed())
    addpath(genpath([cd filesep 'functions']));
    rmpath(genpath([cd filesep 'functions' filesep 'codegen']));
end
%start flimx
if(exist('FLIMXObj','var'))
    try
        if(~isa(FLIMXObj,'FLIMX') || ~FLIMXObj.isvalid)
            clear 'FLIMXObj'
        end        
    end    
end
try
    FLIMXObj = FLIMX();
catch ME
    switch ME.identifier
        case 'FLIMX:FDTree:fileLock'
            str = sprintf('%s\n\nFLIMX appears to be already running. Only one instance at a time is allowed.\nPlease use the other instance or close it before opening a new one.',ME.message);
        otherwise
            str = sprintf('Error launching FLIMX:\n%s\n%s',ME.identifier,ME.message);
    end
    uiwait(errordlg(str,'Error launching FLIMX','modal'));
    pause(0.1);
    clear 'FLIMXObj'
    return
end
FLIMXObj.updateSplashScreenProgressLong(0.9,'Opening GUIs...');
%open GUI(s)
if(FLIMXObj.paramMgr.generalParams.openFitGUIonStartup)
    FLIMXObj.openFLIMXFitGUI();
end
if(~FLIMXObj.paramMgr.generalParams.openFitGUIonStartup || FLIMXObj.paramMgr.generalParams.openVisGUIonStartup)
    %force to open the visualization GUI if both should be set to 0
    FLIMXObj.openFLIMXVisGUI();
end
FLIMXObj.updateSplashScreenProgressLong(1,'FLIMX Startup complete');
pause(0.1);
FLIMXObj.closeSplashScreen();

