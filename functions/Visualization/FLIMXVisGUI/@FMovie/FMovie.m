classdef FMovie < FDisplay
    %=============================================================================================================
    %
    % @file     FMovie.m
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
    % @brief    A class to paint frames for movie export
    %
    properties(GetAccess = protected, SetAccess = protected)
        myDynVisParams = [];
        myStaticVisParams = [];
        myHMainAxes = [];
    end
    properties(GetAccess = public, SetAccess = protected)
        
    end
    properties (Dependent = true)
        
    end
    
    methods
        
        function this = FMovie(FDisplayObj,hAx)
            %
            this = this@FDisplay(FDisplayObj.visObj,FDisplayObj.mySide);
            %set inital values
            this.myDynVisParams = FDisplayObj.dynVisParams;
            this.myStaticVisParams = FDisplayObj.staticVisParams;
            this.myHMainAxes = hAx;
            this.screenshot = true;
        end
        
        %dependent properties helper methods
        function out = getDynVisParams(this)
            %
            out = this.myDynVisParams;
        end
        
        function out = getStaticVisParams(this)
            %
            out = this.myStaticVisParams;
        end
        
        function out = getHandleMainAxes(this)
            %get handle to main axes
            out = this.myHMainAxes;
        end
        
        function setDynVisParams(this,val)
            %
            this.myDynVisParams = val;
        end
        
        function setStaticVisParams(this,val)
            %
            this.myStaticVisParams = val;
        end
        
        function setHandleMainAxes(this,val)
            %
            this.myHMainAxes = val;
        end
        
    end
end