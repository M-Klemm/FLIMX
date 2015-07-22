function hostName = gethostname
%GETHOSTNAME  Get host name.
%		HOSTNAME = GETHOSTNAME returns the name of the computer that MATLAB 
%		is running on. Function should work for both Linux and Windows.
%
%		Markus Buehren
%		Last modified: 30.03.2009
%
%		See also GETUSERNAME.

persistent hostNamePersistent

if isempty(hostNamePersistent)
  if ispc
    hostName = getenv('COMPUTERNAME');
  else
    hostName = getenv('HOSTNAME');
  end
  
  if isempty(hostName)
    % the environment variable above was not existing
    if ispc
      systemCall = 'hostname';
    else
      systemCall = 'uname -n';
    end
    [status, hostName] = system(systemCall);
    if status ~= 0
      error('System call "%s" failed with return code %d.', systemCall, status);
    end
    hostName = hostName(1:end-1);
  end

  % environment variable and system call might result different, so only
  % allow upper case letters
  hostName = upper(hostName);
  
	% save string for next function call
	hostNamePersistent = hostName;
else
	% return string computed before
	hostName = hostNamePersistent;
end
