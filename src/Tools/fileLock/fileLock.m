classdef fileLock < handle
    %=============================================================================================================
    %
    % @file     fileLock.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  1.0
    % @date     August, 2017
    %
    % @section  LICENSE
    %
    % Copyright (C) 2017, Matthias Klemm. All rights reserved.
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
    % @brief    A class to manage a lock file
    %           Modified from https://stackoverflow.com/a/17595762 by Nathan Donnellan
    %
    properties (Access = private)
        myFileName = '';
        myFileHandle = [];
        myFileLock = [];        
    end
    properties (Dependent = true)
        isLocked = false;
    end

    methods
        function this = fileLock(filename)
            %constructor: create the lockfile
            this.myFileName = filename;
            this.myFileHandle = java.io.RandomAccessFile(filename,'rw');
            fileChannel = this.myFileHandle.getChannel();
            this.myFileLock = fileChannel.tryLock();
        end

        function out = get.isLocked(this)
            %return true if file is locked
            if(~isempty(this.myFileLock) && this.myFileLock.isValid())
                out = true;
            else
                out = false;
            end
        end

        function delete(this)
            %destructor
            this.release();
            try
                delete(this.myFileName);
            catch ME
                warning('Could not delete lock file: %s\n%s',this.myFileName,ME.message);
            end
        end

        function release(this)
            %release the lock and delete the file
            if(this.isLocked())
                this.myFileLock.release();
            end
            this.myFileHandle.close
        end
    end
end