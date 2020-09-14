function [head] = PTU_Read_Head(name)
% Read PicoQuant Unified TTTR Files
%
% downloaded from Ingo Grgor and Sumeet Rohilla released under MIT License: https://github.com/PicoQuant/sFLIM released under MIT License
%
% modified by Matthias Klemm <Matthias_Klemm@gmx.net>
%

head = [];
fid = fopen(name);
if(fid < 1)
    %fprintf(1,'\n\n      Could not open <%s>. Aborted.\n', name);
else    
    tyEmpty8      = hex2dec('FFFF0008');
    tyBool8       = hex2dec('00000008');
    tyInt8        = hex2dec('10000008');
    tyBitSet64    = hex2dec('11000008');
    tyColor8      = hex2dec('12000008');
    tyFloat8      = hex2dec('20000008');
    tyTDateTime   = hex2dec('21000008');
    tyFloat8Array = hex2dec('2001FFFF');
    tyAnsiString  = hex2dec('4001FFFF');
    tyWideString  = hex2dec('4002FFFF');
    tyBinaryBlob  = hex2dec('FFFFFFFF');
        
    head.Magic =  deblank(char(fread(fid, 8, 'char')'));
    if not(strcmp(head.Magic,'PQTTTR'))
        error('Magic invalid, this is not an PTU file.');
    end
    head.Version = deblank(char(fread(fid, 8, 'char')'));    
    TagIdent = deblank(char(fread(fid, 32, 'char')'));  % TagHead.Ident
    TagIdent = TagIdent(TagIdent ~= '$');
    TagIdx   = fread(fid, 1, 'int32');                  % TagHead.Idx
    TagTyp   = fread(fid, 1, 'uint32');                 % TagHead.Typ
    
    while(~strcmp(TagIdent, 'Header_End'))               
        if(TagIdx > -1)
            EvalName = [TagIdent '(' int2str(TagIdx + 1) ')'];
        else
            EvalName = [TagIdent];
        end
        EvalName = matlab.lang.makeValidName(EvalName);        
        % check Typ of Header        
        switch TagTyp
            case tyEmpty8
                fread(fid, 1, 'int64');
                head.(EvalName) = [];
            case tyBool8
                TagInt = fread(fid, 1, 'int64');
                if TagInt==0
                    head.(EvalName) =false;
                else
                    head.(EvalName) =true;
                end
            case tyInt8
                TagInt = fread(fid, 1, 'int64');
                head.(EvalName) = TagInt;
            case tyBitSet64
                TagInt = fread(fid, 1, 'int64');
                head.(EvalName) = TagInt;
            case tyColor8
                TagInt = fread(fid, 1, 'int64');
                head.(EvalName) = TagInt;
            case tyFloat8
                TagFloat = fread(fid, 1, 'double');
                head.(EvalName) = TagFloat;
            case tyFloat8Array
                TagInt = floor(fread(fid, 1, 'int64')/8);
                TagArray = fread(fid, TagInt, 'double');
            case tyTDateTime
                TagFloat = fread(fid, 1, 'double');
                head.(EvalName) = datestr(693960+TagFloat);
            case tyAnsiString
                TagInt = fread(fid, 1, 'int64');
                TagString = deblank(char(fread(fid, TagInt, 'char'))');
                tmp = char(regexp(EvalName,'\([0-9]+\)','match'));
                if ~isempty(tmp)
                    EvalName=strrep(EvalName,tmp,['{' tmp(2:end-1) '}']);
                end
                head.(EvalName) = TagString;
            case tyWideString
                % Matlab does not support Widestrings at all, just read and
                % remove the 0's (up to current (2012))
                TagInt = fread(fid, 1, 'int64');
                TagString = fread(fid, TagInt, '*char');
                TagString = (TagString(TagString ~= 0))';
                fprintf(1, '%s', TagString);
                if TagIdx > -1
                    EvalName = [TagIdent '(' int2str(TagIdx + 1) ',:)'];
                end
                head.(EvalName) = TagString;
            case tyBinaryBlob
                TagInt = floor(fread(fid, 1, 'int64')/8);
                TagBytes = fread(fid, 1, 'uint64');
            otherwise
                
        end
        TagIdent = deblank(char(fread(fid, 32, 'char')'));  % TagHead.Ident
        TagIdent = TagIdent(TagIdent ~= '$');
        TagIdx   = fread(fid, 1, 'int32');                  % TagHead.Idx
        TagTyp   = fread(fid, 1, 'uint32');                 % TagHead.Typ
    end    
    head.length = ftell(fid)+8;
    fclose(fid);    
end
