function varargout = FLIMXsplashFigure(varargin)
% FLIMXSPLASHFIGURE MATLAB code for FLIMXsplashFigure.fig
%      FLIMXSPLASHFIGURE, by itself, creates a new FLIMXSPLASHFIGURE or raises the existing
%      singleton*.
%
%      H = FLIMXSPLASHFIGURE returns the handle to a new FLIMXSPLASHFIGURE or the handle to
%      the existing singleton*.
%
%      FLIMXSPLASHFIGURE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in FLIMXSPLASHFIGURE.M with the given input arguments.
%
%      FLIMXSPLASHFIGURE('Property','Value',...) creates a new FLIMXSPLASHFIGURE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before FLIMXsplashFigure_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to FLIMXsplashFigure_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help FLIMXsplashFigure

% Last Modified by GUIDE v2.5 03-Aug-2016 18:02:34

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @FLIMXsplashFigure_OpeningFcn, ...
                   'gui_OutputFcn',  @FLIMXsplashFigure_OutputFcn, ...
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


% --- Executes just before FLIMXsplashFigure is made visible.
function FLIMXsplashFigure_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to FLIMXsplashFigure (see VARARGIN)

% Choose default command line output for FLIMXsplashFigure
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);
set(0,'units','pixels');
ss = get(0,'screensize');
set(handles.FLIMXSplashFigure,'units','pixels','Position',[(ss(3)-500)/2,50+(ss(4)-370-50)/2,500,350],'Name','FLIMX Startup...');
try
    set(handles.buttonSpinner,'String',sprintf('<html><img src="file:/%s"/></html>',FLIMX.getAnimationPath()));
end
try
    img = imread(FLIMX.getLogoPath());
    image(img,'Parent',handles.axesSplash);    
end
axis(handles.axesSplash,'off');
daspect(handles.axesSplash,[1 1 1]);
axis(handles.axesWaitShort,'off');
axis(handles.axesWaitLong,'off');

% UIWAIT makes FLIMXsplashFigure wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = FLIMXsplashFigure_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles;
