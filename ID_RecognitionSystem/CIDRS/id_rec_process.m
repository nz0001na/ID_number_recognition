% use threshold to handle with gray image
% binarization image
function [ id_codes,id_bw,code_stats,thresh,iteration ] = id_rec_process( img_gray,model,thresh,training_data_size,iteration )
narginchk(1,5)
if nargin==1
    model=[];
elseif  nargin<=2 || thresh==0
    % use ostu method to compute threshold
    thresh=.68*graythresh(img_gray);  
elseif nargin<=3
    % define data size [47 31]
    training_data_size=[47 31];
elseif nargin<=4 || isempty(training_data_size)
    iteration=1;
end
% fprintf('Iteration %d, threshold value: %f\n',iteration,thresh)

% im2bw: convert gray image to binarization image
bw=~im2bw(img_gray,thresh);
% imclearborder: Suppress light structures connected to image border
bw=imclearborder(bwareaopen(bw,10));
% imdilate:   dilate function
bwc=imdilate(bw,strel('disk',6));
% count area of marked region
code_stats=regionprops(bwc,'Area');

step_ratio=1.1;  % threshold step size 0.1
if isempty(code_stats) && thresh*step_ratio<1
    [id_codes,id_bw,code_stats,thresh,iteration]=id_rec_process(img_gray,model,thresh*step_ratio,training_data_size,iteration+1);
    return
end

id_codes=blanks(18);
if isempty(code_stats)
    id_bw=bw;
    return
end
[~,midx]=max([code_stats.Area]);
% bwlabel: label connected region of binary image
mask=bwlabel(bwc)==midx;
% imreconstruct: morphological reconstruction 
id_bw=imreconstruct(mask,bw);
code_stats=regionprops(id_bw,'Image','Extent');

if length(code_stats)~=18 && thresh*step_ratio<1
    [id_codes,id_bw,code_stats,thresh,iteration]=id_rec_process(img_gray,model,thresh*step_ratio,training_data_size,iteration+1);
    return
end

if length(code_stats)==18
    inputs=zeros(training_data_size(1)*training_data_size(2),18);
    for i=1:size(inputs,2)
        img=imresize(code_stats(i).Image,training_data_size);
        inputs(:,i)=img(:);
    end
    
    % predict
    if ~isempty(model)
        try
            output=model(inputs);
            [~,midx]=max(output);
            count=size(output,2);
            for i=1:count
                switch midx(i)
                    case 1
                        id_codes(i)='X';
                    otherwise
                        id_codes(i)=num2str(11-midx(i));
                end
            end
        catch e
            disp(e)
            for i=1:length(e.stack)
                disp(e.stack(i))
            end
        end
    end
end
end