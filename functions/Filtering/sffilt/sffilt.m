function B = sffilt(func,A,siz,padopt,CHUNKFACTOR)

%SFFILT Scalar function-based filtering.
%   SFFILT(FUNC,A,...) replaces each element in the 1D, 2D or 3D array A by
%   the scalar issued from the function FUNC applied on the elements in the
%   neighborhood around the corresponding pixel. FUNC must be a scalar
%   function.
%
%   FUNC can be a string that represents a function ('max', 'min', 'mean',
%   'median', 'std', 'var', 'sum', 'prod', 'nanmean',...), a function
%   handle (@max, @median, @sum,...) or an inline function object.
%
%   Some typical filters:
%      'mean' or @mean:      averaging filter
%      'median' or @median:  median filtering
%      'max' or @max:        image dilation
%      'min' or @min:        image erosion
%   Create your own root-mean-square filter:
%      rms = @(x) sqrt(mean(x.^2));
%      B = sffilt(rms,A);
%   
%   B = SFFILT(FUNC,A,[M N P]) performs scalar-function filtering of the
%   3-D array A. Each output pixel contains the scalar FUNC value in the
%   M-by-N-by-P neighborhood around the corresponding pixel in the input
%   array.
%
%   B = SFFILT(FUNC,A,[M N]) performs scalar-function filtering of the
%   matrix A. Each output pixel contains the scalar FUNC value in the
%   M-by-N neighborhood around the corresponding pixel.
%
%   B = SFFILT(FUNC,A,M) performs scalar-function filtering of the vector
%   A. Each output pixel contains the scalar FUNC value in the M
%   neighborhood around the corresponding pixel.
%
%   B = SFFILT(FUNC,A) performs scalar-function filtering using a 3 or 3x3
%   or 3x3x3 neighborhood according to the size of A.
%
%   B = SFFILT(FUNC,A,DOMAIN) replaces each element in A by the scalar
%   calculated from the set of neighbors specified by the nonzero elements
%   in DOMAIN. DOMAIN is equivalent to the structuring element used for
%   binary image operations. It is a matrix containing only 1's and 0's;
%   the 1's define the neighborhood for the filtering operation. For
%   example, B = SFFILT('max',A,[0 1 0; 1 0 1; 0 1 0]) replaces each
%   element in A by the maximum of its north, east, south, and west
%   neighbors. The size of the domain must be odd in each direction.
%
%   B = SFFILT(FUNC,A,...,PADOPT) pads array A using PADOPT option:
%
%      String values for PADOPT (default = 'replicate'):
%      'circular'    Pads with circular repetition of elements.
%      'replicate'   Repeats border elements of A. (DEFAULT)
%      'symmetric'   Pads array with mirror reflections of itself.
%
%      If PADOPT is a scalar, A is padded with this scalar.
%
%   Notes
%   -----
%     IMPORTANT: The scalar function FUNC must work across the first
%     non-singleton dimension by default (e.g. max, min, trapz, mean,
%     median, sum, std, var, prod, nanmean, nanmedian...).
%
%     M, N and P must be odd integers. If not, they are incremented by 1.
%
%     If you do not have the Image Processing Toolbox, A can only be padded
%     with a scalar (default = zero-padding).
%
%     If you work with very large 3D arrays, an "Out of memory" error may
%     appear. The chunk factor (CHUNKFACTOR, default value = 1) must be
%     increased to further reduce the size of the chunks. Use the following
%     syntax: SFFILT(FUNC,A,[...],PADOPT,CHUNKFACTOR).
%
%   Examples
%   --------
%     %>> Some 2-D examples using a 3x3 neighborhood:
%     A = rand(10,10);
%     Amean = sffilt('mean',A); % or Amean = sffilt(@mean,A);
%     Amed = sffilt('median',A);
%     Amax = sffilt('max',A);
%     rms = @(x) sqrt(mean(x.^2)); 
%     Arms = sffilt(rms,A);
%
%     %>> 1-D scalar-function filtering using MEAN <<
%     % This examples uses a mean filter with a 11 neighborhood. 
%     t = linspace(0,2*pi,200);
%     y = cos(t)+(rand(1,200)-0.5)/5;
%     ys = sffilt('mean',y,11);
%     plot(t,y,'g',t,ys,'k')
%
%     %>> 2-D scalar-function filtering using MAX <<
%     % This examples uses a maximum filter with a [5 5] neighborhood. 
%     % This is equivalent to imdilate(image,strel('square',5)).
%     A = imread('snowflakes.png');
%     B = sffilt('max',A,[5 5]);
%     figure, subplot(211), imshow(A), subplot(212), imshow(B)
%
%     %>> 3-D scalar-function filtering using MEDIAN <<
%     % This examples uses a median filter with a [3 3 3] neighborhood. 
%     % This is equivalent to medfilt3(array).
%     rand('state',0)
%     [x,y,z,V] = flow(50);
%     noisyV = V + 0.1*double(rand(size(V))>0.95);
%     clear V
%     figure
%     subplot(121)
%     hpatch = patch(isosurface(x,y,z,noisyV,0));
%     isonormals(x,y,z,noisyV,hpatch)
%     set(hpatch,'FaceColor','red','EdgeColor','none')
%     daspect([1,4,4]), view([-65,20]), axis tight off
%     camlight left; lighting phong 
%     subplot(122)
%     %--------
%     denoisedV = sffilt('median',noisyV);
%     %--------
%     hpatch = patch(isosurface(x,y,z,denoisedV,0));
%     isonormals(x,y,z,denoisedV,hpatch)
%     set(hpatch,'FaceColor','red','EdgeColor','none')
%     daspect([1,4,4]), view([-65,20]), axis tight off
%     camlight left; lighting phong
%       
%   See also MEDFILT3, ORDFILT2, FSPECIAL3
%
%   -- Damien Garcia -- 2008/01, revised 2008/02
%
%   MODIFIED by Matthias Klemm 2015/07 (experimental GPU support)
%

%narginchk(2,5);
error(nargchk(2, 5, nargin, 'struct'));

%% Note:
% If you work with large 3D arrays, an "Out of memory" error may appear.
% The chunk factor thus must be increased to reduce the size of the chunks.
if nargin~=5
    CHUNKFACTOR = 1;
end
if CHUNKFACTOR<1, CHUNKFACTOR = 1; end
%% check if GPU
if(isa(A,'gpuArray'))
    useGPU = true;    
else
    useGPU = false;
end
%% Check if FUNC is a scalar function
if ischar(func), func = strtrim(func); end
try
    B = feval(func,rand(1,3));
    if ~isscalar(B), error(' '), end
catch
    error('FUNC argument is not a scalar function.')
end

%% Check input arguments
if isscalar(A), B = feval(func,A); return, end

if ndims(A)>3
    error('A must be a 1-D, 2-D or 3-D array.')
end

if all(isnan(A(:))), B = A; return, end

sizA = uint16(size(A));
if(useGPU)
    sizA = gpuArray(double(sizA));
end
if nargin==2
    % default kernel size is 3 or 3x3 or 3x3x3
    if isvector(A)
        siz = 3;
    else
        siz = 3*ones(1,numel(sizA));
    end
    padopt = 'replicate';
elseif nargin==3
    % default padding option is "replicate"
    padopt = 'replicate';
end

%% Check if SIZ represents a DOMAIN (i.e. contains only 0 and 1)
test = isequal((siz==0)+(siz==1),true(size(siz)));
if test
    domain = logical(siz);    
    siz = size(domain);
    if any(rem(siz,2)==0)
        error('The size of the domain must be odd.')
    end
else
    I = rem(siz,2)==0;
    siz(I) = siz(I)+1;
    if(useGPU)
        domain = gpuArray.true(siz);
    else
        domain = true(siz);
    end
end

%% Make SIZ a 3-element array
if numel(siz)==2
    siz = [siz 1];
elseif isscalar(siz)
    if sizA(1)==1
        siz = [1 siz 1];
    else
        siz = [siz 1 1];
    end
end

%% Chunks: the numerical process is split up in order to avoid large arrays
N = uint32(numel(A));
n = prod(siz);
siz = (siz-1)/2;
if(N <= 65536 && CHUNKFACTOR == 1)
    nchunk = [uint32(1) N];
else
    nchunk = uint32((1:ceil(double(N)/n/CHUNKFACTOR):N));
end
if nchunk(end)~=N, nchunk = [nchunk N]; end
if(useGPU)
    nchunk = gpuArray(nchunk);
end

%% Check if FUNC works with other classes than single and double
class0 = class(A);
if ~isa(A,'float')
    try
        feval(func,uint8(0));
    catch
        A = double(A);
    end
end

%% Padding along specified direction
% If PADARRAY exists (Image Processing Toolbox), this function is used.
% Otherwise the array is padded with scalars.
B = A;
sizB = sizA;
try
    A = padarray(A,siz,padopt);
catch
    if ~isscalar(padopt)
        padopt = 0;
        warning('MATLAB:sffilt:InexistentPadarrayFunction',...
            ['PADARRAY function does not exist: '...
            'only scalar padding option is available.\n'...
            'If not specified, the scalar 0 is used as default.']);
    end
    A = ones(sizB+siz(1:ndims(B))*2,'like',A)*padopt;
    A(siz(1)+1:end-siz(1),siz(2)+1:end-siz(2),siz(3)+1:end-siz(3)) = B;
end

sizA = int32(size(A));
if(useGPU)
    sizA = gpuArray(sizA);
end

if numel(sizB)==2
    sizA = [sizA 1];
    sizB = [sizB 1];
end

%% Creating the index arrays (INT32)
inc = zeros([3 2*siz+1],'like',sizA);
if(useGPU)
    
else
    siz = int32(siz);
end
[inc(1,:,:,:), inc(2,:,:,:), inc(3,:,:,:)] = ndgrid(...
    [0:-1:-siz(1) 1:siz(1)],...
    [0:-1:-siz(2) 1:siz(2)],...
    [0:-1:-siz(3) 1:siz(3)]);
inc = reshape(inc,[1 3 prod(2*single(siz)+1)]);

I = zeros([sizB 3],'like',sizA);
if(useGPU)
    
else
    sizB = int32(sizB);
end
[I(:,:,:,1), I(:,:,:,2), I(:,:,:,3)] = ndgrid(...
    (1:sizB(1))+siz(1),...
    (1:sizB(2))+siz(2),...
    (1:sizB(3))+siz(3));
I = reshape(I,[prod(single(sizB)) 3]);

%% Filtering
for i = 1:length(nchunk)-1

    Im = repmat(I(nchunk(i):nchunk(i+1),:),[1 1 n]);
    Im = Im + repmat(inc,[nchunk(i+1)-nchunk(i)+1,1,1]);
    I0 = Im(:,1,:) +...
        (Im(:,2,:)-1)*sizA(1) +...
        (Im(:,3,:)-1)*sizA(1)*sizA(2);
    I0 = squeeze(I0);
    if i==1
        [~,tmpI] = sort(I0(1,:));
        domain = domain(tmpI);
        clear tmp*
    end
    I0 = I0(:,domain(:));
    if ~isvector(I0)
        B(nchunk(i):nchunk(i+1)) = feval(func,A(I0'));
    else
        % Matlab functions work across the first non-singleton dimension.
        % One must do a pixel-by-pixel evaluation (loop!) if I0 is a vector.
        for j = nchunk(i):nchunk(i+1)
            B(j) = feval(func,A(I0(j-nchunk(i)+1)));
        end
    end

end

%% Change the class
if(useGPU)
    B = gather(B);
else
    B = cast(B,class0);
end