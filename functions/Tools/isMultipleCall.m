function flag=isMultipleCall()
% isMultipleCall checks the stack for multiple calls
% 
% isMultipleCall checks to see if multiple calls are present in the call
% stack to the function from which isMultipleCall was called.
% 
% Example:
% TF=isMultipleCall()
% 
% returns     true  if the stack contains more than one call to the
%                   function that called isMultipleCall
%             false otherwise
%
% See also dbstack
%
% -------------------------------------------------------------------------
% Author: Malcolm Lidierth 11/09
% Copyright © The Author & King's College London 2009-
% -------------------------------------------------------------------------

flag=false; 
% Get the stack
s=dbstack();
if numel(s)<=2
    % Stack too short for a multiple call
    return
end
% How many calls to the calling function are in the stack?
names={s(1:end).name};
TF=strcmp(s(2).name,names);
count=sum(TF);
if count>1
    % More than 1
    flag=true; 
end
return
end
   
