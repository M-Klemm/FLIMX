function startmulticoreslave(multicoreDir)
%STARTMULTICORESLAVE  Start multi-core processing slave process.
%   STARTMULTICORESLAVE(DIRNAME) starts a slave process for function
%   STARTMULTICOREMASTER. The given directory DIRNAME is checked for data
%   files including which function to run and which parameters to use.
%
%   STARTMULTICORESLAVE (without input arguments) uses the directory
%   <TEMPDIR>/multicorefiles, where <TEMPDIR> is the directory returned by
%   function tempdir.
%
%		Markus Buehren
%		Last modified 10.04.2009
%
%   See also STARTMULTICOREMASTER.

debugMode    = 0;
showWarnings = 0;

if debugMode
    % activate all messages
    showWarnings = 1;
end

% parameters
firstWarnTime = 10;
startWarnTime = 10*60;
maxWarnTime   = 24*3600;
startWaitTime = 0.5;
maxWaitTime   = 5;

if debugMode
    firstWarnTime = 10;
    startWarnTime = 10;
    maxWarnTime   = 60;
    maxWaitTime   = 1;
end

persistent lastSessionDateStr

% get slave file directory name
if ~exist('multicoreDir', 'var') || isempty(multicoreDir)
    multicoreDir = fullfile(tempdir2, 'multicorefiles');
end
if ~isfolder(multicoreDir)
    [status, message, ~] = mkdir(multicoreDir);
    if(~status)
        error('multicore:startmulticoreslave','Unable to create slave file directory %s.\n%s', multicoreDir,message);
    end
end

% initialize variables
lastEvalEndClock = clock;
lastWarnClock    = clock;
firstRun         = true;
curWarnTime      = firstWarnTime;
curWaitTime      = startWaitTime;
%MKlemm
lastParPoolRefresh = clock; 
try
    hashEngine = java.security.MessageDigest.getInstance('MD5');
catch
    hashEngine = [];
end

while 1
    % find current working dir
    curDirs = dir(multicoreDir);
    curDirs = curDirs([curDirs.isdir]); %select only dirs
    curDirs = curDirs(~strncmp({curDirs.name},'.',1));
    curDirs = curDirs(~strncmp({curDirs.name},'logs',4));
    [~,idx]= sort([curDirs.datenum],'descend');
    curDirs = curDirs(idx);
    parameterFileList = cell(0,0);
    if(~isempty(curDirs))
        for i = 1:length(curDirs)
            try
                parameterFileList = findfiles(fullfile(multicoreDir,curDirs(i).name), 'parameters_*.mat', 'nonrecursive');
            catch
                continue
            end
            if(~isempty(parameterFileList))
                break
            end
        end
    end
    
    
    % Buehren 29.07.2012: Randomly select a parameter file. This minimizes the
    % number of collisions (different Matlab sessions trying to access the same
    % parameter file) when a large number of slave sessions is used.
    parameterFileName = '';
    fileIndex = randperm(length(parameterFileList));
    for fileNr = 1:length(fileIndex)
        if isempty(strfind(parameterFileList{fileIndex(fileNr)}, 'semaphore'))
            parameterFileName = parameterFileList{fileIndex(fileNr)};

%     % get last file that is not a semaphore file
%     parameterFileName = '';
%     for fileNr = length(parameterFileList):-1:1
%         if isempty(strfind(parameterFileList{fileNr}, 'semaphore'))
%             parameterFileName = parameterFileList{fileNr};
            break % leave the for-loop
        end
    end
    
    if ~isempty(parameterFileName)
        if debugMode
            % get parameter file number for debug messages
            fileNr = str2double(regexptokens(parameterFileName,'parameters_\d+_(\d+)\.mat'));
            fprintf('****** Slave is checking file nr %d *******\n\r\n', fileNr);
        end
        
        % load and delete last parameter file
        %sem = setfilesemaphore(parameterFileName);
        % try to rename parameter file
        parameterFileNameTmp = strrep(parameterFileName, '.mat', sprintf('.%s_%d',gethostname(),round(rand*10^10)));
        loadSuccessful = false;
        parameters = [];
        parametersHash = 0;
        if existfile(parameterFileName)
            % try to load the parameters
            lastwarn('');
            lasterror('reset');
            workingFile = strrep(parameterFileName, 'parameters', 'working');
            workingFile = strrep(workingFile, '.mat', sprintf('.%s_%d',gethostname(),round(rand*10^10)));
            try
                %rename file to reserve it for this worker
                moveStatus = movefile(parameterFileName,parameterFileNameTmp);
                if(moveStatus)
                    % renaming was successful -> no other slave can get this file                    
                    % Generate a temporary file which shows when the slave started working.
                    % Using this file, the master can decide if the job timed out.
                    % Still using the semaphore of the parameter file above.                    
                    generateemptyfile(workingFile);
                    if debugMode
                        fprintf('Working file nr %d generated.\n', fileNr);
                    end        
                    load(parameterFileNameTmp,'-mat', 'functionHandles', 'parameters', 'parametersHash'); %% file access %%
                    loadSuccessful = true;
                    if(any(parametersHash) && ~isempty(hashEngine))
                        %we do have a parameter hash -> compute the hash to check if parameters are ok
                        hashEngine.reset();
                        hashEngine.update(getByteStreamFromArray(parameters));
                        myParamHash = typecast(hashEngine.digest, 'uint8');
                        if(length(myParamHash(:)) ~= length(parametersHash(:)) || ~all(myParamHash(:) == parametersHash(:)))
                            fprintf('Warning: Parameter file %s was ignored because hash value did not match.\n', parameterFileName);
                            loadSuccessful = false;
                        end
                    end
                end
            catch
                %loadSuccessful = false;
                if showWarnings
                    fprintf('Warning: Unable to load parameter file %s.\n\r\n', parameterFileName);
                    lastMsg = lastwarn;
                    if ~isempty(lastMsg)
                        fprintf('Warning message issued when trying to load:\n%s\n\r\n', lastMsg);
                    end
                    displayerrorstruct;
                end
            end
            
            % check if variables to load are existing
            if(loadSuccessful)
                if((~exist('functionHandles', 'var') || ~exist('parameters', 'var') || isempty(parameters)))
                    loadSuccessful = false;
                    if showWarnings
                        disp(textwrap2(sprintf(['Warning: Either variable ''%s'' or ''%s''', ...
                            'or ''%s'' not existing after loading file %s.'], ...
                            'functionHandles', 'parameters', parameterFileName)));
                    end
                elseif(~iscell(parameters) || isempty(parameters{1}) || numel(parameters{1,1}{1,1}) < 1 || ~isa(parameters{1,1}{1,1}{1,1},'fluoPixelModel'))
                    %file load seemed successful, yet something went wrong
                    %->wait and try again
                    pause(0.5);
                    try
                        load(parameterFileNameTmp,'-mat', 'functionHandles', 'parameters', 'parametersHash'); %% file access %%
                        loadSuccessful = true;
                        if(any(parametersHash) && ~isempty(hashEngine))
                            %we do have a parameter hash -> compute the hash to check if parameters are ok
                            hashEngine.reset();
                            hashEngine.update(getByteStreamFromArray(parameters));
                            myParamHash = typecast(hashEngine.digest, 'uint8');
                            if(length(myParamHash(:)) ~= length(parametersHash(:)) || ~all(myParamHash(:) == parametersHash(:)))
                                fprintf('Warning: Parameter file %s was ignored because hash value did not match.\n', parameterFileName);                            
                                loadSuccessful = false;
                            end
                        end
                    catch
                        if showWarnings
                            fprintf('Warning: Unable to load parameter file %s.\n\r\n', parameterFileName);
                            lastMsg = lastwarn;
                            if ~isempty(lastMsg)
                                fprintf('Warning message issued when trying to load:\n%s\n\r\n', lastMsg);
                            end
                            displayerrorstruct;
                        end
                    end
                    if(~iscell(parameters) || isempty(parameters{1}) || numel(parameters{1,1}{1,1}) < 1 || ~isa(parameters{1,1}{1,1}{1,1},'fluoPixelModel'))
                        loadSuccessful = false;
                    end
                end
            end
            
            if debugMode
                if loadSuccessful
                    fprintf('Successfully loaded parameter file nr %d.\n', fileNr);
                else
                    fprintf('Problems loading parameter file nr %d.\n', fileNr);
                end
            end
            % remove semaphore and continue if loading was not successful
            if ~loadSuccessful
                %removefilesemaphore(sem);
                mbdelete(workingFile, showWarnings); %% file access %%
                pause(0.5+0.5*rand);
                continue
            end
            % remove parameter file
            deleteSuccessful = mbdelete(parameterFileNameTmp, showWarnings); %% file access %%
            if ~deleteSuccessful
                % If deletion is not successful it can happen that other slaves or
                % the master also use these parameters. To avoid this, ignore the
                % loaded parameters
                %loadSuccessful = false;
                if debugMode
                    fprintf('Problems deleting parameter file nr %d. It will be ignored\n', fileNr);
                end
                %removefilesemaphore(sem);
                pause(0.5+0.5*rand);
                continue
            end
            %check function handles
            for k=1:numel(parameters)
                if(isa(functionHandles{k}, 'function_handle'))
                    %convert to string and try to find (local) function handle again
                    fName = func2str(char(functionHandles{k}));
                    functionHandles{k} = str2func(fName);
                    if(~isa(functionHandles{k}, 'function_handle'))
                        fprintf('Function handle for %s not found! Aborting...\n',fName);
                        return
                    end
                elseif(ischar(functionHandles{k}))
                    %get handle to function
                    fName = functionHandles{k};
                    functionHandles{k} = str2func(functionHandles{k});
                    if(~isa(functionHandles{k}, 'function_handle'))
                        fprintf('Function handle for %s not found! Aborting...\n',fName);
                        return
                    end
                end
            end
        else
            %loadSuccessful = false;
            if debugMode
                disp('No parameter files found.');
            end
        end
        
        % remove semaphore file
        %removefilesemaphore(sem);
        
        % show progress info
        if firstRun
            fprintf('First function evaluation (%s)\n\r\n', datestr(clock, 'mmm dd, HH:MM'));
            firstRun = false;
        elseif etime(clock, lastEvalEndClock) > 60
            fprintf('First function evaluation after %s (%s)\n\r\n', ...
                formattime(etime(clock, lastEvalEndClock)), datestr(clock, 'mmm dd, HH:MM'));
        end
        
        %%%%%%%%%%%%%%%%%%%%%
        % evaluate function %
        %%%%%%%%%%%%%%%%%%%%%
        if debugMode
            fprintf('Slave evaluates job nr %d.\n', fileNr);
            t0 = mbtime;
        end
        
        % Check if date string in parameter file name has changed. If yes, call
        % "clear functions" to ensure that the latest file versions are used,
        % no older versions in Matlab's memory.
        sessionDateStr = regexptokens(parameterFileName, 'parameters_(\d+)_\d+\.mat');
        if ~strcmp(sessionDateStr, lastSessionDateStr)
            clear functions
            
            %if debugMode
            disp('New multicore session detected, "clear functions" called.');
            %end
        end
        lastSessionDateStr = sessionDateStr;
        
        result = cell(size(parameters)); %#ok
        for k=1:numel(parameters)
            if iscell(parameters{k})
                result{k} = feval(functionHandles{k}, parameters{k}{:}); %#ok
            else
                result{k} = feval(functionHandles{k}, parameters{k}); %#ok
            end
        end
        if debugMode
            fprintf('Slave finished job nr %d in %.2f seconds.\n', fileNr, mbtime - t0);
        end
        if(all(cellfun('isempty',result)))
            fprintf('%s produced an empty result (nr %d; file %s). Result was not saved.',gethostname(),fileNr,parameterFileName);
            %save(strrep(parameterFileName, 'parameters', 'error_param'),'parameters');
            % remove working file
            mbdelete(workingFile, showWarnings); %% file access %%
            % Save result. Use file semaphore of the parameter file to reduce the overhead.
        elseif(isfolder(multicoreDir) && existfile(workingFile)) %do nothing if multicore dir or working file have been removed
            %sem = setfilesemaphore(parameterFileName);
            resultFileName = strrep(parameterFileName, 'parameters', 'result');
            [tPath,tFN] = fileparts(resultFileName);
            resultFileNameTmp = fullfile(tPath,[tFN '.tmp']);
            try
                save(resultFileNameTmp, 'result'); %% file access %%
                [renameStatus,renameMsg,renameMsgID] = movefile(resultFileNameTmp,resultFileName); %% file access %%
                if(~renameStatus)
                    disp(textwrap2(sprintf('Warning: Unable to rename file: %s.\nMsg: %s', resultFileName,renameMsg)));
                end
                if debugMode
                    fprintf('Result file nr %d generated.\n', fileNr);
                end
            catch
                if showWarnings
                    fprintf('Warning: Unable to save file %s.\n', resultFileName);
                    displayerrorstruct;
                end
            end
            
            % remove working file
            mbdelete(workingFile, showWarnings); %% file access %%
            if debugMode
                fprintf('Working file nr %d deleted.\n', fileNr);
            end
            
            % remove parameter file (might have been re-generated again by master)
            mbdelete(parameterFileName, showWarnings); %% file access %%
            if debugMode
                fprintf('Parameter file nr %d deleted.\n', fileNr);
            end
            
            % remove semaphore
            %removefilesemaphore(sem);
        end
        % save time
        lastEvalEndClock = clock;
        curWarnTime = startWarnTime;
        curWaitTime = startWaitTime;
        
        % remove variables before next run
        clear result functionHandle parameters
        
    else
        % display message if idle for long time
        timeSinceLastEvaluation = etime(clock, lastEvalEndClock);
        if min(timeSinceLastEvaluation, etime(clock, lastWarnClock)) > curWarnTime
            if timeSinceLastEvaluation >= 10*60
                % round to minutes
                timeSinceLastEvaluation = 60 * round(timeSinceLastEvaluation / 60);
            end
            fprintf('Warning: No slave files found during last %s (%s).\n\r\n', ...
                formattime(timeSinceLastEvaluation), datestr(clock, 'mmm dd, HH:MM'));
            lastWarnClock = clock;
            if firstRun
                curWarnTime = startWarnTime;
            else
                curWarnTime = min(curWarnTime * 2, maxWarnTime);
            end
            curWaitTime = min(curWaitTime + 0.5, maxWaitTime);
        end
        %MKlemm
        p = gcp('nocreate');
        if(~isempty(p) && ~isa(p,'parallel.ThreadPool'))
            if(min(etime(clock, lastEvalEndClock), etime(clock, lastParPoolRefresh))/60 >= (p.IdleTimeout/2)) %waited at least half the idle timeout
                %refresh idle timer of parpool by doing something stupid
                parfor i = 1:10
                    y(i) = sin(i);
                end
                clear y
                lastParPoolRefresh = clock;
            end
        end
        
        % wait before next check
        pause(curWaitTime);
        
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function timeString = formattime(time, mode)
%FORMATTIME  Return formatted time string.
%   STR = FORMATTIME(TIME) returns a formatted time string for the given
%   time difference TIME in seconds, i.e. '1 hour and 5 minutes' for TIME =
%   3900.
%
%   FORMATTIME(TIME, MODE) uses the specified display mode ('long' or
%   'short'). Default is long display.
%
%   FORMATTIME (without input arguments) shows examples.

if nargin == 0
    fprintf('\nExamples for strings returned by function %s.m:\n', mfilename);
    time = [0 1e-4 0.1 1 1.1 2 60 61 62 120 121 122 3600 3660 3720 7200 7260 7320 ...
        3600*24 3600*25 3600*26 3600*48 3600*49 3600*50];
    for k=1:length(time)
        fprintf('time = %6g, timeString = ''%s''\n', time(k), formattime(time(k)));
    end
    if nargout > 0
        timeString = '';
    end
    return
end

if ~exist('mode', 'var')
    mode = 'long';
end

if time < 0
    disp('Warning: Time must be greater or equal zero.');
    timeString = '';
elseif time >= 3600*24
    days = floor(time / (3600*24));
    if days > 1
        dayString = 'days';
    else
        dayString = 'day';
    end
    hours = floor(mod(time, 3600*24) / 3600);
    if hours == 0
        timeString = sprintf('%d %s', days, dayString);
    else
        if hours > 1
            hourString = 'hours';
        else
            hourString = 'hour';
        end
        timeString = sprintf('%d %s and %d %s', days, dayString, hours, hourString);
    end
    
elseif time >= 3600
    hours = floor(mod(time, 3600*24) / 3600);
    if hours > 1
        hourString = 'hours';
    else
        hourString = 'hour';
    end
    minutes = floor(mod(time, 3600) / 60);
    if minutes == 0
        timeString = sprintf('%d %s', hours, hourString);
    else
        if minutes > 1
            minuteString = 'minutes';
        else
            minuteString = 'minute';
        end
        timeString = sprintf('%d %s and %d %s', hours, hourString, minutes, minuteString);
    end
    
elseif time >= 60
    minutes = floor(time / 60);
    if minutes > 1
        minuteString = 'minutes';
    else
        minuteString = 'minute';
    end
    seconds = floor(mod(time, 60));
    if seconds == 0
        timeString = sprintf('%d %s', minutes, minuteString);
    else
        if seconds > 1
            secondString = 'seconds';
        else
            secondString = 'second';
        end
        timeString = sprintf('%d %s and %d %s', minutes, minuteString, seconds, secondString);
    end
    
else
    if time > 10
        seconds = floor(time);
    else
        seconds = floor(time * 100) / 100;
    end
    if seconds > 0
        if seconds ~= 1
            timeString = sprintf('%.4g seconds', seconds);
        else
            timeString = '1 second';
        end
    else
        timeString = sprintf('%.4g seconds', time);
    end
end

switch mode
    case 'long'
        % do nothing
    case 'short'
        timeString = strrep(timeString, ' and ', ' ');
        timeString = strrep(timeString, ' days', 'd');
        timeString = strrep(timeString, ' day', 'd');
        timeString = strrep(timeString, ' hours', 'h');
        timeString = strrep(timeString, ' hour', 'h');
        timeString = strrep(timeString, ' minutes', 'm');
        timeString = strrep(timeString, ' minute', 'm');
        timeString = strrep(timeString, ' seconds', 's');
        timeString = strrep(timeString, ' second', 's');
    otherwise
        error('Mode ''%s'' unknown in function %s.', mode, mfilename);
end


