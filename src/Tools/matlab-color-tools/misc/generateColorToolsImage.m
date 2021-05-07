function generateToolboxImage
%

% Steve Eddins
% Copyright 2018-2019, The MathWorks, Inc.

[x,y] = ndgrid(-10:.02:10);
theta = atan2(y,x);
rho = hypot(x,y);
X = im2uint8(mat2gray(theta));
rgb = ind2rgb(X,parula(256));
rgb_256 = imresize(rgb,[256 256]);
alpha_mask = (rho <= 10);
alpha_mask = conv2(double(alpha_mask),ones(3,3)/9,'same');
alpha_mask_256 = imresize(alpha_mask,[256 256]);
imwrite(rgb_256,'color-toolbox-image.png','Alpha',alpha_mask_256)
