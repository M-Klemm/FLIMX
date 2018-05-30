function idx = moveMaskToPixelPosition(mask,pixelYPos,pixelXPos,dataYSz,dataXSz,binXcoord, binYcoord)
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here

rows = any(mask,1);
cols = any(mask,2);
Ym = int32(binYcoord(rows,cols));
Xm = int32(binXcoord(rows,cols));
mask = mask(rows,cols);
%move mask to coordinates of pixel position
Ym(:) = Ym(:) + pixelYPos;
Xm(:) = Xm(:) + pixelXPos;
%coordinates must be between 1 and size of the data matrix
mask = mask & Ym <= dataYSz & Ym > 0 & Xm <= dataXSz & Xm > 0;
%             idx = sub2ind([dataYSz,dataXSz],tmpYcoord(mask),tmpXcoord(mask));
idx = Ym(mask)+dataYSz.*(Xm(mask)-1);

end

