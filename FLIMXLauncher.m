%opens FLIMX, a tool to approximate and analyze FLIM parameters
%(e.g. amplitude, lifetime) of measurements or simulations

%check Matlab version
nr = version('-release');
if(~(str2double(nr(1:4)) > 2014 || str2double(nr(1:4)) == 2014 && strcmp(nr(end),'b')))
    uiwait(errordlg(sprintf('Your MATLAB version is R%s. This software requires MATLAB R2014b or newer. Please update your MATLAB installation.',nr),'MATLAB version too old','modal'));
    return
end
clear nr;
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
            FLIMXObj = FLIMX();
        end        
    end    
else
    FLIMXObj = FLIMX();
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

