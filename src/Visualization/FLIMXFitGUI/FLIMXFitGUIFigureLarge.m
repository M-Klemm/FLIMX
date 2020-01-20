function varargout = FLIMXFitGUIFigureLarge(varargin)
%=============================================================================================================
%
% @file     FLIMXFitGUIFigureLarge.m
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
% @brief    The main FLIMXFit GUI (large version)
%
% FLIMXFitGUIFIGURELARGE M-file for FLIMXFitGUIFigureLarge.fig
%      FLIMXFitGUIFIGURELARGE, by itself, creates a new FLIMXFitGUIFIGURELARGE or raises the existing
%      singleton*.
%
%      H = FLIMXFitGUIFIGURELARGE returns the handle to a new FLIMXFitGUIFIGURELARGE or the handle to
%      the existing singleton*.
%
%      FLIMXFitGUIFIGURELARGE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in FLIMXFitGUIFIGURELARGE.M with the given input arguments.
%
%      FLIMXFitGUIFIGURELARGE('Property','Value',...) creates a new FLIMXFitGUIFIGURELARGE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before FLIMXFitGUIFigureLarge_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to FLIMXFitGUIFigureLarge_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help FLIMXFitGUIFigureLarge

% Last Modified by GUIDE v2.5 06-Jan-2011 14:46:01

% Begin initialization code - DO NOT EDIT
gui_Singleton = 0;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @FLIMXFitGUIFigureLarge_OpeningFcn, ...
                   'gui_OutputFcn',  @FLIMXFitGUIFigureLarge_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before FLIMXFitGUIFigureLarge is made visible.
function FLIMXFitGUIFigureLarge_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to FLIMXFitGUIFigureLarge (see VARARGIN)

% Choose default command line output for FLIMXFitGUIFigureLarge
%handles.output = handles;
handles.mySize = 3; %I'm large

% Update handles structure
guidata(hObject, handles);
movegui(handles.FLIMXFitGUIFigure,'northwest');

% UIWAIT makes FLIMXFitGUIFigureLarge wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = FLIMXFitGUIFigureLarge_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles;
