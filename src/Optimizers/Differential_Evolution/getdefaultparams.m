function DEParamsDefault = getdefaultparams
%GETDEFAULTPARAMS  Get default parameters for differential evolution.
%		DEParams = GETDEFAULTPARAMS returns a structure with a set of default
%		parameters for differential evolution.
%
%		Markus Buehren
%		Last modified 09.08.2008 
%
%		See also DIFFERENTIALEVOLUTION.

% DE parameters
DEParamsDefault.algorithm      = 'DE';
DEParamsDefault.CR             = 0.7;
DEParamsDefault.F              = 0.8;
DEParamsDefault.NP             = 30;
DEParamsDefault.VTR            = NaN;
DEParamsDefault.strategy       = 1;

% parameters for reinitialization of population
DEParamsDefault.minvalstddev   = -1;
DEParamsDefault.minparamstddev = -1;
DEParamsDefault.nofevaliter    = 10;
DEParamsDefault.nochangeiter   = 10;

% parameters for finishing the optimization
DEParamsDefault.maxiter        = inf;
DEParamsDefault.maxtime        = inf;  % in seconds
DEParamsDefault.maxclock       = [];   % time vector as returned by clock.m

% parameters for information display
DEParamsDefault.refreshiter    = 10;
DEParamsDefault.refreshtime    = 60;   % in seconds
DEParamsDefault.refreshtime2   = 600;  % in seconds
DEParamsDefault.refreshtime3   = 1800; % in seconds

% slave process parameters
DEParamsDefault.feedSlaveProc  = 0;
DEParamsDefault.slaveFileDir   = '';
DEParamsDefault.maxMasterEvals = inf;

% miscellaneous
DEParamsDefault.useInitParams  = 1;
DEParamsDefault.saveHistory    = 1;
DEParamsDefault.displayResults = 1;
DEParamsDefault.playSound      = 1;
DEParamsDefault.minimizeValue  = 1;
DEParamsDefault.validChkHandle = '';


