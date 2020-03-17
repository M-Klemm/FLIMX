function exportExcel(fn,data,columnHeader,rowHeader,sheetName,tableName)
%=============================================================================================================
%
% @file     exportExcel.m
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
% @brief    A  function to write data to excel file fn
%
%input arguments: filename, data, columnHeader, rowHeader, sheetName, tableName
[pathstr, name, ext] = fileparts(fn);
if(~iscell(data))
    data = num2cell(data);
end
dataRow = 1; dataCol = 1;
ex = cell(size(data));
if(length(rowHeader) == size(data,1))
    dataCol = 2;
    ex(2:end+1,1) = rowHeader;
end
if(~isempty(tableName))
    ex(1,1) = {tableName};
    dataRow = 2;
end
if(length(columnHeader) == size(data,2))    
    ex(1,dataCol:length(columnHeader)+dataCol-1) = columnHeader;    
    dataRow = 2;
end
ex(dataRow:dataRow+size(data,1)-1,dataCol:dataCol+size(data,2)-1) = data;
sheetName = sheetName(1:min(length(sheetName),31));
%max 65536 rows
if(size(ex,1) > 65536)
    uiwait(warndlg(sprintf('Export data contains %d rows. Excel is restricted to 65536 rows.\nRow 65537 and all following are not included in the Excel File.\nReduce number of rows to include all data in export.',size(ex,1)),'Too many rows','modal'));
    ex = ex(1:65536,:);
    
end
%max 256 columns
parts = ceil(size(ex,2)/256);
if(parts > 1)
    uiwait(warndlg(sprintf('Export data contains %d columns. Excel is restricted to 256 columns.\nThe data is split across multiple files.\nReduce number of columns to include all data in a single excel file.',size(ex,2)),'Too many columns','modal'));
    for i = 1:parts
        [pathstr, name, ext] = fileparts(fn);
        exportExcel(sprintf('%s_part%d%s',fullfile(pathstr, name),i,ext),ex(:,(i-1)*256+1:min(i*256,size(ex,2))),[],[],sheetName,[]);
    end
    return
end
warning('off','MATLAB:xlswrite:AddSheet');
try
    %xlswrite(fn, ex,sheetName,'A1'); %, sheet, range) %write a sheet and to specific position in sheet
    writecell(ex,fn,'FileType','spreadsheet','Sheet',sheetName,'Range','A1'); %write a sheet and to specific position in sheet
catch ME
    errordlg(sprintf('Exporting Excel file failed. Is the target file still opened in Excel?\n\nError Code: ''%s''',ME.message),'Error: Excel Export failed','modal');
end
warning('on','MATLAB:xlswrite:AddSheet');