function tests = xyz2ciecam02_test
tests = functiontests(localfunctions);
end

function Fairchild_Table_16_4_Case_1_test(testcase)
% Reference: Mark D. Fairchild, Color Appearance Models, 3rd
% edition, John Wiley & Sons, 2013, p. 299.

XYZ = [0.1901 0.2000 0.2178];
XYZ_w = [0.9505 1.0000 1.0888];
L_A = 318.31;
Y_b = 0.20;
surround = 'average';
out = xyz2ciecam02(XYZ,XYZ_w,L_A,Y_b,surround);

% Absolute tolerances based on the number of significant digits
% given in Table 16.4.
verifyEqual(testcase,out.J,41.73,'AbsTol',1e-2);
verifyEqual(testcase,out.Q,195.37,'AbsTol',1e-2);
verifyEqual(testcase,out.C,0.10,'AbsTol',1e-2);
verifyEqual(testcase,out.M,0.11,'AbsTol',1e-2);
verifyEqual(testcase,out.s,2.36,'AbsTol',1e-2);
verifyEqual(testcase,out.h,219.0,'AbsTol',1e-1);
verifyEqual(testcase,out.H,278.1,'AbsTol',1e-1);
end

function Fairchild_Table_16_4_Case_2_test(testcase)
% Reference: Mark D. Fairchild, Color Appearance Models, 3rd
% edition, John Wiley & Sons, 2013, p. 299.

XYZ = [0.5706 0.4306 0.3196];
XYZ_w = [0.9505 1.0000 1.0888];
L_A = 31.83;
Y_b = 0.20;
surround = 'average';
out = xyz2ciecam02(XYZ,XYZ_w,L_A,Y_b,surround);

% Absolute tolerances based on the number of significant digits
% given in Table 16.4. Higher tolerance (0.3 instead of 0.1) used
% for out.H.
verifyEqual(testcase,out.J,65.96,'AbsTol',1e-2);
verifyEqual(testcase,out.Q,152.67,'AbsTol',1e-2);
verifyEqual(testcase,out.C,48.57,'AbsTol',1e-2);
verifyEqual(testcase,out.M,41.67,'AbsTol',1e-2);
verifyEqual(testcase,out.s,52.25,'AbsTol',1e-2);
verifyEqual(testcase,out.h,19.6,'AbsTol',1e-1);
verifyEqual(testcase,out.H,399.6,'AbsTol',3e-1);
end

function Fairchild_Table_16_4_Case_3_test(testcase)
% Reference: Mark D. Fairchild, Color Appearance Models, 3rd
% edition, John Wiley & Sons, 2013, p. 299.

XYZ = [0.0353 0.0656 0.0214];
XYZ_w = [1.0985 1.0000 0.3558];
L_A = 318.31;
Y_b = 0.20;
surround = 'average';
out = xyz2ciecam02(XYZ,XYZ_w,L_A,Y_b,surround);

% Absolute tolerances based on the number of significant digits
% given in Table 16.4. 
verifyEqual(testcase,out.J,21.79,'AbsTol',1e-2);
verifyEqual(testcase,out.Q,141.17,'AbsTol',1e-2);
verifyEqual(testcase,out.C,46.94,'AbsTol',1e-2);
verifyEqual(testcase,out.M,48.80,'AbsTol',1e-2);
verifyEqual(testcase,out.s,58.79,'AbsTol',1e-2);
verifyEqual(testcase,out.h,177.1,'AbsTol',1e-1);
verifyEqual(testcase,out.H,220.4,'AbsTol',1e-1);
end

function Fairchild_Table_16_4_Case_4_test(testcase)
% Reference: Mark D. Fairchild, Color Appearance Models, 3rd
% edition, John Wiley & Sons, 2013, p. 299.

XYZ = [0.1901 0.2000 0.2178];
XYZ_w = [1.0985 1.0000 0.3558];
L_A = 31.83;
Y_b = 0.20;
surround = 'average';
out = xyz2ciecam02(XYZ,XYZ_w,L_A,Y_b,surround);

% Absolute tolerances based on the number of significant digits
% given in Table 16.4. Higher tolerance (0.4 instead of 0.1) for
% out.H.
verifyEqual(testcase,out.J,42.53,'AbsTol',1e-2);
verifyEqual(testcase,out.Q,122.83,'AbsTol',1e-2);
verifyEqual(testcase,out.C,51.92,'AbsTol',1e-2);
verifyEqual(testcase,out.M,44.54,'AbsTol',1e-2);
verifyEqual(testcase,out.s,60.22,'AbsTol',1e-2);
verifyEqual(testcase,out.h,248.9,'AbsTol',1e-1);
verifyEqual(testcase,out.H,305.8,'AbsTol',4e-1);
end