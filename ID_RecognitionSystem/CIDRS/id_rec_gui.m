function varargout = id_rec_gui(varargin)
% ID_REC_GUI MATLAB code for id_rec_gui.fig
%      ID_REC_GUI, by itself, creates a new ID_REC_GUI or raises the existing
%      singleton*.
%
%      H = ID_REC_GUI returns the handle to a new ID_REC_GUI or the handle to
%      the existing singleton*.
%
%      ID_REC_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in ID_REC_GUI.M with the given input arguments.
%
%      ID_REC_GUI('Property','Value',...) creates a new ID_REC_GUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before id_rec_gui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to id_rec_gui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help id_rec_gui

% Last Modified by GUIDE v2.5 28-May-2013 11:48:47

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @id_rec_gui_OpeningFcn, ...
    'gui_OutputFcn',  @id_rec_gui_OutputFcn, ...
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


% --- Executes just before id_rec_gui is made visible.
function id_rec_gui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to id_rec_gui (see VARARGIN)

% Choose default command line output for id_rec_gui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes id_rec_gui wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = id_rec_gui_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in browse.
function browse_Callback(hObject, eventdata, handles)
% hObject    handle to browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global pathname filenames
% uigetfile:  file open dialog
% 0 means canceling files selection
[filenames,pathname]=uigetfile({'*.bmp;*.jpg;*.png;*.gif','All Image Files';'*.*','All Files' },'MultiSelect','on');
if ~isequal(filenames,0)
    init_controls(handles) 
    preprocess(handles)
    process(handles)
end

% initialize the controls of GUI
function init_controls(handles)
global filenames current_select_idx
current_select_idx=1;
if ischar(filenames)
    filenames={filenames};
end
if ischar(filenames) || length(filenames)==1
    set(handles.img_idx,'String','')
    set(handles.img_idx_slider,'Visible','off')
else
    set(handles.img_idx_slider,'Visible','on')
    set(handles.img_idx_slider,'Min',0)
    set(handles.img_idx_slider,'Max',length(filenames)-1)
    set(handles.img_idx_slider,'SliderStep',ones(1,2)/(length(filenames)-1))
end
set(handles.validate,'Enable','on')

% read_id_card by filename
function [org_img,img_gray,thresh_value]=read_id_card(filename)
% imfinfo: read image info 
fileinfo=imfinfo(filename);  
if strcmpi(fileinfo.ColorType,'indexed') 
    [X,map]=imread(filename);
    org_img=ind2rgb(X,map);  % convert index image to color image
else
    org_img=imread(filename);
end
r=size(org_img,1);
c=size(org_img,2);
size_thresh=2000;  
% resize images
if r>size_thresh
    org_img=imresize(org_img,size_thresh/r);
end
if c>size_thresh
    org_img=imresize(org_img,size_thresh/c);
end
org_img=im2double(org_img);
% get gray image
% ndims: get dimension of org_img
if ndims(org_img)==3
    img_gray=rgb2gray(org_img);
else
    img_gray=org_img;
end
img_gray=imresize(img_gray,[350 500]);
img_gray=img_gray(round(size(img_gray,1)*2/3):end,round(size(img_gray,2)/4):end);
% graythresh: use otsu method to get threshold
thresh_value=.68*graythresh(img_gray);

% preprocess, show original image on panels
function preprocess(handles)
global pathname filenames current_select_idx img_gray
if length(filenames)>1
    img_idx_str=sprintf('%d / %d',current_select_idx,length(filenames));
    set(handles.img_idx,'String',img_idx_str)
    set(handles.img_idx_slider,'Value',current_select_idx-1)
    set(handles.img_idx_slider,'TooltipString',img_idx_str)
end
try
    % fullfile: construct full path of image
    filename=fullfile(pathname,filenames{current_select_idx});
    [org_img,img_gray,thresh_value]=read_id_card(filename);
    axes(handles.img)
    % show original image on GUI
    imshow(org_img),title(filename,'Interpreter','None')
    set(handles.thresh_value,'Visible','on')
    set(handles.thresh_value,'value',thresh_value)
catch e
    msgbox(sprintf('Cannot read the image: %s.\n\n',filename,e.message),'Error','error')
    rethrow(e)
end

% segmentation result panel
function process(handles)
global code_stats img_gray model filenames current_select_idx area_codes training_data_size
if isequal(filenames,0) || isempty(filenames)
    return
end
% init all characters of ID number controls ?segmentation result?
for i=1:18
    set(eval(sprintf('handles.result%d',i)),'BackgroundColor',[1 1 1])
    set(eval(sprintf('handles.result%d',i)),'Enable','Inactive')
    set(eval(sprintf('handles.result%d',i)),'String','')
end
set(handles.birthday,'BackgroundColor',[1 1 1])
set(handles.birthday,'String','')
set(handles.ID_code,'BackgroundColor',[1 1 1])
set(handles.ID_code,'String','')
set(handles.gender,'BackgroundColor',[1 1 1])
set(handles.gender,'String','')
set(handles.address,'BackgroundColor',[1 1 1])
set(handles.address,'String','')
set(handles.save_results,'Enable','off')

% process gray image, show binary image
thresh=get(handles.thresh_value,'value');
[id_codes,id_bw,code_stats,thresh,iteration]=id_rec_process(img_gray,model,thresh,training_data_size,1);
% if isempty(id_codes)
%     msgbox('Cannot recognize ID codes. You can try adjusting the threshold value.','Warning','warn','modal')
%     return
% end
axes(handles.bw)
imshow(padarray(id_bw,[130 0],'pre')),title(sprintf('Current threshold: %.4f, %d iteration(s)',thresh,iteration))
set(handles.thresh_value,'value',thresh)
set(handles.thresh_value,'TooltipString',num2str(thresh))

id_error_flag=0;
birthday_error_flag=0;
gender_error_flag=0;
address_error_flag=0;
for i=1:min([length(id_codes) length(code_stats)])
    % show segmentation in seg axes and result text
    axes(eval(sprintf('handles.seg%d',i)))
    imshow(code_stats(i).Image)
    set(eval(sprintf('handles.result%d',i)),'String',id_codes(i))
    % compare readed characters of binary image with ground truth-filename
    if length(filenames{current_select_idx})<i || ~strcmpi(id_codes(i),filenames{current_select_idx}(i))
        id_error_flag=1;
        % the first six digits stand for address
        if i<=6
            address_error_flag=1;
        % the 7th to 14th means birthday
        elseif i>=7 && i<=14
            birthday_error_flag=1;
        % the 17th means gender
        elseif i==17 && (length(filenames{current_select_idx})<i || mod(id_codes(i),2)~=mod(filenames{current_select_idx}(i),2))
            gender_error_flag=1;
        end
        set(eval(sprintf('handles.result%d',i)),'BackgroundColor',[1 0 0])
        set(eval(sprintf('handles.result%d',i)),'Enable','on')
    end
end
set(handles.save_results,'Enable','on')

% set results in result textboxes
% set ID number
set(handles.ID_code,'String',id_codes)
if id_error_flag
    set(handles.ID_code,'BackgroundColor',[1 0 0])
end
% set birthday
set(handles.birthday,'String',id_codes(7:14))
if birthday_error_flag
    set(handles.birthday,'BackgroundColor',[1 0 0])
end
% set gender
if mod(id_codes(17),2)
    set(handles.gender,'String','Male')
else
    set(handles.gender,'String','Female')
end
if gender_error_flag
    set(handles.gender,'BackgroundColor',[1 0 0])
end
% set address
try
    address=area_codes{uint32(str2double(id_codes(1:6)))};
    if isempty(address)
        address=area_codes{uint32(str2double(id_codes(1:4)))};
    end
    if isempty(address)
        address=area_codes{uint32(str2double(id_codes(1:2)))};
    end
    if isempty(address)
        set(handles.address,'String','NO RECORD')
    else
        set(handles.address,'String',address)
    end
    if address_error_flag || isempty(address)
        set(handles.address,'BackgroundColor',[1 0 0])
    end
catch e
    set(handles.address,'String','NO RECORD')
    set(handles.address,'BackgroundColor',[1 0 0])
end


% --- Executes on button press in exit.
function exit_Callback(hObject, eventdata, handles)
% hObject    handle to exit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
close(gcf)


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
if strcmp(questdlg('Do you really want to exit the system?','Exit'),'Yes')
    delete(hObject);
    clear all
end



function ID_code_Callback(hObject, eventdata, handles)
% hObject    handle to ID_code (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ID_code as text
%        str2double(get(hObject,'String')) returns contents of ID_code as a double


% --- Executes during object creation, after setting all properties.
function ID_code_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ID_code (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in save_results.
% save all segmented images(18) in data_dir
function save_results_Callback(hObject, eventdata, handles)
% hObject    handle to save_results (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global filenames current_select_idx code_stats training_data_size
data_dir=fullfile('CIDRS','IDcard_recognition',sprintf('%d_%d',training_data_size(1),training_data_size(2)),'training_data');
if strcmp(questdlg(sprintf('Do you want to save the training data into "%s"?',data_dir),'Information'),'Yes')
    seq=zeros(11,1);
    h=waitbar(0,'Initializing...');
    count=length(code_stats);
    for i=1:count
        result=get(eval(sprintf('handles.result%d',i)),'String');
        if ~isempty(regexpi(result,'^[0-9X]$'))
            img=imresize(code_stats(i).Image,training_data_size);
            filename=filenames{current_select_idx};
            switch result
                case 'X'
                    seq(end)=seq(end)+1;
                    name=fullfile('X',sprintf('%s_%d',filename(1:strfind(filename,'.')-1),seq(end)));
                otherwise
                    % 0-9
                    d=uint8(str2double(result));
                    seq(d+1)=seq(d+1)+1;
                    name=fullfile(result,sprintf('%s_%d',filename(1:strfind(filename,'.')-1),seq(d+1)));
            end
            imwrite(img,fullfile(data_dir,[name '.bmp']) )
        end
        waitbar(i/count,h,sprintf('Saved %4.2f%%...',100*i/count))
    end
    close(h)
end


function result1_Callback(hObject, eventdata, handles)
% hObject    handle to result1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result1 as text
%        str2double(get(hObject,'String')) returns contents of result1 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result2_Callback(hObject, eventdata, handles)
% hObject    handle to result2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result2 as text
%        str2double(get(hObject,'String')) returns contents of result2 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result3_Callback(hObject, eventdata, handles)
% hObject    handle to result3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result3 as text
%        str2double(get(hObject,'String')) returns contents of result3 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result4_Callback(hObject, eventdata, handles)
% hObject    handle to result4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result4 as text
%        str2double(get(hObject,'String')) returns contents of result4 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result5_Callback(hObject, eventdata, handles)
% hObject    handle to result5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result5 as text
%        str2double(get(hObject,'String')) returns contents of result5 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result6_Callback(hObject, eventdata, handles)
% hObject    handle to result6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result6 as text
%        str2double(get(hObject,'String')) returns contents of result6 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result7_Callback(hObject, eventdata, handles)
% hObject    handle to result7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result7 as text
%        str2double(get(hObject,'String')) returns contents of result7 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result7_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result12_Callback(hObject, eventdata, handles)
% hObject    handle to result12 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result12 as text
%        str2double(get(hObject,'String')) returns contents of result12 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result12_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result12 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result8_Callback(hObject, eventdata, handles)
% hObject    handle to result8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result8 as text
%        str2double(get(hObject,'String')) returns contents of result8 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result8_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function result15_Callback(hObject, eventdata, handles)
% hObject    handle to result15 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result15 as text
%        str2double(get(hObject,'String')) returns contents of result15 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result15_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result15 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result16_Callback(hObject, eventdata, handles)
% hObject    handle to result16 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result16 as text
%        str2double(get(hObject,'String')) returns contents of result16 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result16_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result16 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result17_Callback(hObject, eventdata, handles)
% hObject    handle to result17 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result17 as text
%        str2double(get(hObject,'String')) returns contents of result17 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result17_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result17 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result18_Callback(hObject, eventdata, handles)
% hObject    handle to result18 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result18 as text
%        str2double(get(hObject,'String')) returns contents of result18 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result18_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result18 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result14_Callback(hObject, eventdata, handles)
% hObject    handle to result14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result14 as text
%        str2double(get(hObject,'String')) returns contents of result14 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result14_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result11_Callback(hObject, eventdata, handles)
% hObject    handle to result11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result11 as text
%        str2double(get(hObject,'String')) returns contents of result11 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result11_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result9_Callback(hObject, eventdata, handles)
% hObject    handle to result9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result9 as text
%        str2double(get(hObject,'String')) returns contents of result9 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result9_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result13_Callback(hObject, eventdata, handles)
% hObject    handle to result13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result13 as text
%        str2double(get(hObject,'String')) returns contents of result13 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result13_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function result10_Callback(hObject, eventdata, handles)
% hObject    handle to result10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of result10 as text
%        str2double(get(hObject,'String')) returns contents of result10 as a double
result_KeyPressCallback(hObject)


% --- Executes during object creation, after setting all properties.
function result10_CreateFcn(hObject, eventdata, handles)
% hObject    handle to result10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
% create segmented image folders
function figure1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
global training_data_size
% call init_data function
init_data
set(hObject,'Name',sprintf('%s - [%d %d]',get(hObject,'Name'),training_data_size(1),training_data_size(2)))
base_path=fullfile('CIDRS','IDcard_recognition',sprintf('%d_%d',training_data_size(1),training_data_size(2)),'training_data');
create_folder(fullfile(base_path,'X'))
for i=0:9
    create_folder(fullfile(base_path,num2str(i)))
end

% create folder
function create_folder(folder)
if isempty(dir(folder))
    mkdir(folder)
    fprintf('Create folder "%s" success.\n',folder)
end

% --- Executes on button press in reload_model.
% reload trained model
function reload_model_Callback(hObject, eventdata, handles)
% hObject    handle to reload_model (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global filenames current_select_idx training_data_size
try
    net=evalin('base','net');
    model_file=fullfile('CIDRS','IDcard_recognition',sprintf('%d_%d',training_data_size(1),training_data_size(2)),'model.mat');
    if strcmp(questdlg(sprintf('Do you want to save and reload the model "%s" you have trained?',model_file),'Information'),'Yes')
        if ~isempty(dir(model_file))
            movefile(model_file,[model_file '.' datestr(clock,'yyyymmddHHMMSS')])
        end
        save(model_file,'net')
        init_data
        if ~isequal(filenames,0) && ~isempty(filenames)
            if(strcmp(questdlg(sprintf('Load model "%s" successfully. Do you want to reprocess the image "%s"?',model_file,filenames{current_select_idx}),'Information'),'Yes'))
                process(handles)
            end
        else
            msgbox(sprintf('Load model "%s" successfully.',model_file),'Information','help')
        end
        set(hObject,'Enable','off')
    end
catch e
    if strcmp(questdlg('You haven''t trained model. Do you want to train model now?','Information'),'Yes')
        train_Callback(hObject, eventdata, handles)
    end
end

% initialize global data
function init_data
global area_codes training_data_size
% load area codes
file_name=fullfile('CIDRS','IDcard_recognition','area_code.txt');
fileID=fopen(file_name,'r+','n','utf-8');
if fileID==-1
    warndlg(sprintf('Unable to read file  %s.',file_name),'Warning')
else
%     count = 3415;
%     area_codes1 = {};
%     for i=1:count
%         tline=fgetl(fileID);
%         tline = native2unicode(tline);
%         name = regexp(tline, '\t', 'split');  
%         area_codes1{i} = name;
%     end
%      fclose(fileID);  
    C=textscan(fileID,'%d\t%s');
    fclose(fileID);
    area_codes=cell(999999,1);
    count=size(C{2},1);
    for i=1:count
        area_codes{C{1}(i)}=C{2}{i};
    end
end

% load config.properties
file_name=fullfile('CIDRS','IDcard_recognition','config.properties');
fileID=fopen(file_name);
if fileID==-1
    training_data_size=[47 31];
else
    C=textscan(fileID,'%s%d_%d','delimiter','=');
    fclose(fileID);
    training_data_size=[C{2}(1) C{3}(1)];
end
load_model

% load trained model
function load_model
global model training_data_size
try
    % load model
    load(fullfile('CIDRS','IDcard_recognition',sprintf('%d_%d',training_data_size(1),training_data_size(2)),'model.mat'))
    model=net;
catch e
    warndlg(e.message,'Warning')
end


% --- Executes on slider movement.
function thresh_value_Callback(hObject, eventdata, handles)
% hObject    handle to thresh_value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
thresh=get(handles.thresh_value,'value');
set(hObject,'TooltipString',num2str(thresh))
process(handles)


% --- Executes during object creation, after setting all properties.
function thresh_value_CreateFcn(hObject, eventdata, handles)
% hObject    handle to thresh_value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

function result_KeyPressCallback(obj)
value=strtrim(get(obj,'String'));
set(obj,'String',value);
if isempty(regexpi(value,'^[0-9X]$'))
    set(obj,'BackgroundColor',[1 1 0])
else
    set(obj,'BackgroundColor',[0 1 1])
end


function birthday_Callback(hObject, eventdata, handles)
% hObject    handle to birthday (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of birthday as text
%        str2double(get(hObject,'String')) returns contents of birthday as a double


% --- Executes during object creation, after setting all properties.
function birthday_CreateFcn(hObject, eventdata, handles)
% hObject    handle to birthday (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function gender_Callback(hObject, eventdata, handles)
% hObject    handle to gender (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of gender as text
%        str2double(get(hObject,'String')) returns contents of gender as a double


% --- Executes during object creation, after setting all properties.
function gender_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gender (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function address_Callback(hObject, eventdata, handles)
% hObject    handle to address (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of address as text
%        str2double(get(hObject,'String')) returns contents of address as a double


% --- Executes during object creation, after setting all properties.
function address_CreateFcn(hObject, eventdata, handles)
% hObject    handle to address (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function img_idx_slider_Callback(hObject, eventdata, handles)
% hObject    handle to img_idx_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
global current_select_idx
img_idx=round(get(hObject,'Value'));
current_select_idx=img_idx+1;
preprocess(handles)
process(handles)



% --- Executes during object creation, after setting all properties.
function img_idx_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to img_idx_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in train.
% train model buttopn:
function train_Callback(hObject, eventdata, handles)
% hObject    handle to train (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global training_data_size
% load training data from folders
[inputs,targets]=id_rec_load_training_data(fullfile('CIDRS','IDcard_recognition',sprintf('%d_%d',training_data_size(1),training_data_size(2)),'training_data'));
assignin('base','inputs',inputs)
assignin('base','targets',targets)
nprtool
set(handles.reload_model,'Enable','on')


% --- Executes on button press in validate.
function validate_Callback(hObject, eventdata, handles)
% hObject    handle to validate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global pathname filenames model training_data_size
if isequal(filenames,0) || isempty(filenames)
    warndlg('Cannot validate files, please reload the files you''ll want to validate.','Warning')
    return
end

model_file=fullfile('CIDRS','IDcard_recognition',sprintf('%d_%d',training_data_size(1),training_data_size(2)),'model.mat');
if strcmp(questdlg(sprintf('Do you want to validate the %d files using "%s"?',length(filenames),model_file),'Information'),'Yes')
    set(hObject,'Enable','off')
    h=waitbar(0,'Initializing...','Name',model_file,'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(h,'canceling',0)
    count=length(filenames);
    id_error_count=0;
    id_total_count=0;
    code_error_count=0;
    error_filenames={};
    tic
    for i=1:count
        id_total_count=id_total_count+1;
        if getappdata(h,'canceling')
            break
        end
        error_flag=0;
        try
            [~,img_gray,thresh_value]=read_id_card(fullfile(pathname,filenames{i}));
            id_codes=id_rec_process(img_gray,model,thresh_value,training_data_size);
            if length(id_codes)~=18
                error_flag=1;
                code_error_count=code_error_count+18;
            else
                for j=1:length(id_codes)
                    if ~strcmpi(id_codes(j),filenames{i}(j))
                        error_flag=1;
                        code_error_count=code_error_count+1;
                    end
                end
            end
        catch e
            error_flag=1;
            code_error_count=code_error_count+18;
        end
        if error_flag
            id_error_count=id_error_count+1;
            error_filenames{id_error_count}=filenames{i};
        end
        waitbar(i/count,h,sprintf('Validated %4.2f%% file(s), %d failure file(s)...',100*i/count,id_error_count))
    end
    t=toc;
    delete(h)
    code_total_count=18*id_total_count;
    msg=sprintf(['Model: %s\n\n'...
        'Successful Cards: %d\n'...
        'Total Cards: %d\n'...
        'Successful Percent(%%): %4.2f\n\n'...
        'Successful Codes: %d\n'...
        'Total Codes: %d\n'...
        'Successful Percent(%%): %4.2f\n\n'...
        'Total Time(s): %4.2f\n'...
        'Average Time(s): %4.2f\n\n'],...
        model_file,id_total_count-id_error_count,id_total_count,...
        100*(id_total_count-id_error_count)/id_total_count,...
        code_total_count-code_error_count,...
        code_total_count,...
        100*(code_total_count-code_error_count)/code_total_count,...
        t,t/id_total_count);
    if ~id_error_count
        msgbox(msg,'Validation Report','help','modal')
    else
        load_failure_msg=sprintf('Load (%d) Failure File(s)',id_error_count);
        if strcmp(questdlg(msg,'Validation Report',load_failure_msg,'Cancel','Cancel'),load_failure_msg)
            filenames=error_filenames;
            init_controls(handles)
            preprocess(handles)
            process(handles)
        end
    end
    set(hObject,'Enable','on')
end
