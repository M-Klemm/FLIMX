function tests = ciecam022xyz_test
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

J = 41.73;
Q = 195.37;
C = 0.10;
M = 0.11;
s = 2.36;
h = 219.0;
H = 278.1;
in = table(J,Q,C,M,s,h,H);
out = ciecam022xyz(in,XYZ_w,L_A,Y_b,surround);

% Absolute tolerances based on the number of significant digits
% given in Table 16.4.
verifyEqual(testcase,out,[0.1901 0.2000 0.2178],'AbsTol',1e-4);
end

function Fairchild_Table_16_4_Case_2_test(testcase)
% Reference: Mark D. Fairchild, Color Appearance Models, 3rd
% edition, John Wiley & Sons, 2013, p. 299.

XYZ = [0.5706 0.4306 0.3196];
XYZ_w = [0.9505 1.0000 1.0888];
L_A = 31.83;
Y_b = 0.20;
surround = 'average';
J = 65.96;
Q = 152.67;
C = 48.57;
M = 41.67;
s = 52.25;
h = 19.6;
H = 399.6;
in = table(J,Q,C,M,s,h,H);
out = ciecam022xyz(in,XYZ_w,L_A,Y_b,surround);

% Absolute tolerances based on the number of significant digits
% given in Table 16.4. Z tolerance is a little higher.
verifyEqual(testcase,out,[0.5706 0.4306 0.3196],'AbsTol',3e-4);
end

function Fairchild_Table_16_4_Case_3_test(testcase)
% Reference: Mark D. Fairchild, Color Appearance Models, 3rd
% edition, John Wiley & Sons, 2013, p. 299.

XYZ = [0.0353 0.0656 0.0214];
XYZ_w = [1.0985 1.0000 0.3558];
L_A = 318.31;
Y_b = 0.20;
surround = 'average';
J = 21.79;
Q = 141.17;
C = 46.94;
M = 48.80;
s = 58.79;
h = 177.1;
H = 220.4;
in = table(J,Q,C,M,s,h,H);
out = ciecam022xyz(in,XYZ_w,L_A,Y_b,surround);

% Absolute tolerances based on the number of significant digits
% given in Table 16.4. 
verifyEqual(testcase,out,[0.0353 0.0656 0.0214],'AbsTol',1e-4);
end

function Fairchild_Table_16_4_Case_4_test(testcase)
% Reference: Mark D. Fairchild, Color Appearance Models, 3rd
% edition, John Wiley & Sons, 2013, p. 299.

XYZ = [0.1901 0.2000 0.2178];
XYZ_w = [1.0985 1.0000 0.3558];
L_A = 31.83;
Y_b = 0.20;
surround = 'average';
J = 42.53;
Q = 122.83;
C = 51.92;
M = 44.54;
s = 60.22;
h = 248.9;
H = 305.8;
in = table(J,Q,C,M,s,h,H);
out = ciecam022xyz(in,XYZ_w,L_A,Y_b,surround);

% Absolute tolerances based on the number of significant digits
% given in Table 16.4. 
verifyEqual(testcase,out,[0.1901 0.2000 0.2178],'AbsTol',1e-4);
end