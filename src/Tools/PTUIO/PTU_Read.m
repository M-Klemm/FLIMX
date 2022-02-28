function [sync, tcspc, chan, special, num, loc, head] = PTU_Read(name, cnts, head)
%
%  function [sync, tcspc, chan, special, num] = HT3_Read(name, cnts, head)
%
%  This function reads single-photon data from the file 'name'
%
%  If 'cnts' contains a number larger than 0, the routine reads 'cnts'
%  records the data stream or up the end of the file.
%
%  If 'cnts' contains two numbers [cnts(1) cnts(2)], the routine proceeds
%  to the position cnts(1) before readinf the cnts(2) records of data.
%
%  The output variables contain the followig data:
%  sync    : number of the sync events that preceeded this detection event
%  tcspc   : number of the tcspc-bin of the event
%  chan    : number of the input channel of the event (detector-number)
%  special : indicator of the event-type (0: photon; else : virtual photon)
%  num     : counter of the records that were actually read
%  loc     : number of overcounts after last valid photon
%
% downloaded from Ingo Grgor and Sumeet Rohilla released under MIT License: https://github.com/PicoQuant/sFLIM 
%
% modified by Matthias Klemm <Matthias_Klemm@gmx.net>
%

rtPicoHarpT3     = hex2dec('00010303');% (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $03 (T3), HW: $03 (PicoHarp)
rtPicoHarpT2     = hex2dec('00010203');% (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $02 (T2), HW: $03 (PicoHarp)
rtHydraHarpT3    = hex2dec('00010304');% (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $03 (T3), HW: $04 (HydraHarp)
rtHydraHarpT2    = hex2dec('00010204');% (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $02 (T2), HW: $04 (HydraHarp)
rtHydraHarp2T3   = hex2dec('01010304');% (SubID = $01 ,RecFmt: $01) (V2), T-Mode: $03 (T3), HW: $04 (HydraHarp)
rtHydraHarp2T2   = hex2dec('01010204');% (SubID = $01 ,RecFmt: $01) (V2), T-Mode: $02 (T2), HW: $04 (HydraHarp)
rtTimeHarp260NT3 = hex2dec('00010305');% (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $03 (T3), HW: $05 (TimeHarp260N)
rtTimeHarp260NT2 = hex2dec('00010205');% (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $02 (T2), HW: $05 (TimeHarp260N)
rtTimeHarp260PT3 = hex2dec('00010306');% (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $03 (T3), HW: $06 (TimeHarp260P)
rtTimeHarp260PT2 = hex2dec('00010206');% (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $02 (T2), HW: $06 (TimeHarp260P)
rtMultiHarpNT3   = hex2dec('00010307');% (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $03 (T3), HW: $07 (MultiHarp150N)
rtMultiHarpNT2   = hex2dec('00010207');% (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $02 (T2), HW: $07 (MultiHarp150N)

if(nargin <3 || isempty(head))
    head = PTU_Read_Head(name);
end
if(~isempty(head))
    if(nargin <2 || isempty(cnts))
        cnts = [0 0];
    end
    if(numel(cnts) < 2)
        cnts = [0 cnts];
    end
    if(cnts(2) > 0)
        fid = fopen(name);
        if(fid < 1)
            fprintf(1,'\n\n      Could not open <%s>. Aborted.\n', name);
        else
            fseek(fid, head.length, 'bof');
            if(cnts(1) > 1)
                fseek(fid, 4*(cnts(1)-1), 'cof');
            end
            [T3Record, num] = fread(fid, cnts(2), 'ubit32'); % all 32 bits:
            switch head.TTResultFormat_TTTRRecType
                case rtPicoHarpT3
                    WRAPAROUND = 65536;
                    sync    = uint64(bitand(T3Record,65535));              % the lowest 16 bits:
                    chan    = uint8(bitand(bitshift(T3Record,-28),15));   % the upper 4 bits:
                    tcspc   = uint16(bitand(bitshift(T3Record,-16),4095));
                    special = uint8(chan==15).*uint8(bitand(tcspc,15));
                    ind = ((chan==15) & bitand(tcspc,15)==0);
                case rtPicoHarpT2
                    WRAPAROUND = 210698240;
                    sync    = uint64(bitand(T3Record,268435455));         %the lowest 28 bits
                    tcspc   = uint16(bitand(T3Record,15));                %the lowest 4 bits
                    chan    = uint8(bitand(bitshift(T3Record,-28),15));  %the next 4 bits
                    special = uint8(chan==15).*uint8(bitand(tcspc,15));
                    ind = ((chan == 15) & bitand(tcspc,15) == 0);
                case {rtHydraHarpT3, rtHydraHarp2T3, rtTimeHarp260NT3, rtTimeHarp260PT3,rtMultiHarpNT3}
                    WRAPAROUND = 1024;
                    %   +----------------------+ T3 32 bit record  +---------------------+
                    %   |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
                    %   +-------------------------------+  +-------------------------------+
                    sync = uint64(bitand(T3Record,1023));       % the lowest 10 bits:
                    %   +-------------------------------+  +-------------------------------+
                    %   | | | | | | | | | | | | | | | | |  | | | | | | |x|x|x|x|x|x|x|x|x|x|
                    %   +-------------------------------+  +-------------------------------+
                    tcspc = uint16(bitand(bitshift(T3Record,-10),32767));   % the next 15 bits:
                    %   the dtime unit depends on "Resolution" that can be obtained from header
                    %   +-------------------------------+  +-------------------------------+
                    %   | | | | | | | |x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x| | | | | | | | | | |
                    %   +-------------------------------+  +-------------------------------+
                    chan = uint8(bitand(bitshift(T3Record,-25),63));   % the next 6 bits:
                    %   +-------------------------------+  +-------------------------------+
                    %   | |x|x|x|x|x|x| | | | | | | | | |  | | | | | | | | | | | | | | | | |
                    %   +-------------------------------+  +-------------------------------+
                    special = uint8(bitand(T3Record,2147483648)>0);   % the last bit:
                    %   +-------------------------------+  +-------------------------------+
                    %   |x| | | | | | | | | | | | | | | |  | | | | | | | | | | | | | | | | |
                    %   +-------------------------------+  +-------------------------------+
                    ind = (special == 1 & chan == 63);
                    special = special.*chan;
                case rtHydraHarpT2
                    WRAPAROUND = 33552000;
                    sync    = uint64(bitand(T3Record,33554431));           % the last 25 bits
                    chan    = uint8(bitand(bitshift(T3Record,-25),63));   % the next 6 bits
                    tcspc   = uint16(bitand(chan,15));
                    special = uint8(bitand(bitshift(T3Record,-31),1));    % the last bit
                    ind = (special == 1 & chan == 63);
                    special = special.*chan;
                case {rtHydraHarp2T2, rtTimeHarp260NT2, rtTimeHarp260PT2,rtMultiHarpNT2}
                    WRAPAROUND = 33554432;
                    sync    = uint64(bitand(T3Record,33554431));           % the last 25 bits
                    chan    = uint8(bitand(bitshift(T3Record,-25),63));   % the next 6 bits
                    tcspc   = uint16(bitand(chan,15));
                    special = uint8(bitand(bitshift(T3Record,-31),1));    % the last bit
                    ind = (special == 1 & chan == 63);
                    special = special.*chan;
                otherwise
                    error('Illegal RecordType!');
            end
            tmp  = sync(ind == 1);
            tmp(tmp == 0) = 1;
            sync(ind) = tmp;
            sync = sync + uint64(WRAPAROUND)*cumsum(uint64(ind).*sync);
            sync(ind)    = [];
            tcspc(ind)   = [];
            special(ind) = [];
            chan(ind)    = [];
            loc = num - find(ind == 0,1,'last');
        end
        %         sync = uint32(sync);
        %         tcspc = uint16(tcspc);
        %         special = uint8(special);
        %         chan = uint8(chan);
        fclose(fid);
    else
        sync = uint64([]);
        tcspc = uint16([]);
        special = uint8([]);
        chan = uint8([]);
        num = 0;
        loc = [];
        %         if (nargin<1)||isempty(name)
        %             fprintf(1,'\n\n      You have to specify a valid file-name. Aborted.\n');
        %         %else
        %             %fprintf(1,'\n\n      Could not open <%s>. Aborted.\n', name);
        %         end
    end
end
