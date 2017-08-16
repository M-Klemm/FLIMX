function out = DirSize(dirIn)
%DirSize Determine the size of a directory in bytes.
%   bytes = DirSize(dirIn) Recursively searches the directory indicated by
%   the string dirIn and all of its subdirectories, summing up the file
%   sizes as it goes.  
%   
%   Example:
%   ________
%       DirSize(pwd)./(1024*1024)  %Returns size of the current directory
%       in megabytes.

%Richard Moore
%April 17, 2013

% originDir = pwd;
% cd(dirIn);

a = dir(dirIn);
out = 0;
for x = 1:1:numel(a)
    %Check to make sure that this part of 'a' is an actual file or
    %subdirectory.  
    if ~strcmp(a(x).name,'.')&&~strcmp(a(x).name,'..')
        %Add up the sizes.
        out = out + a(x).bytes;
        if a(x).isdir 
            %Ooooooh, recursive!  Fancy!
            out = out + DirSize([dirIn '\' a(x).name]);
        end
    end
end

% cd(originDir);