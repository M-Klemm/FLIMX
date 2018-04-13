function varargout = splashFigure(varargin)
% SPLASHFIGURE MATLAB code for splashFigure.fig
%      SPLASHFIGURE, by itself, creates a new SPLASHFIGURE or raises the existing
%      singleton*.
%
%      H = SPLASHFIGURE returns the handle to a new SPLASHFIGURE or the handle to
%      the existing singleton*.
%
%      SPLASHFIGURE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SPLASHFIGURE.M with the given input arguments.
%
%      SPLASHFIGURE('Property','Value',...) creates a new SPLASHFIGURE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before splashFigure_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to splashFigure_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help splashFigure

% Last Modified by GUIDE v2.5 03-Aug-2016 17:20:13

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @splashFigure_OpeningFcn, ...
                   'gui_OutputFcn',  @splashFigure_OutputFcn, ...
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


% --- Executes just before splashFigure is made visible.
function splashFigure_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to splashFigure (see VARARGIN)

% Choose default command line output for splashFigure
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);
set(0,'units','pixels');
ss = get(0,'screensize');
set(handles.FLIMXSplashFigure,'units','pixels','Position',[(ss(3)-500)/2,50+(ss(4)-350-50)/2,500,350],'Name','FLIMX Startup...');
try
    set(handles.buttonSpinner,'String',sprintf('<html><img src="file:/%s"/></html>',FLIMX.getAnimationPath()));
end
try
    img = imread(FLIMX.getLogoPath());
    image(img,'Parent',handles.axesSplash);    
end
axis(handles.axesSplash,'off');
axis(handles.axesShortBar,'off');
axis(handles.axesLongBar,'off');

% UIWAIT makes splashFigure wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = splashFigure_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles;
