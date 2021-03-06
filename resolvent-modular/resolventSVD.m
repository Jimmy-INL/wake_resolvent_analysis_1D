function [r,su,ss,sv,U0,dU0,dr] = resolventSVD(filename,Ld,Re,k,n,om,N,rc2,rmax,nsvd)
% This code computes the singular value decomposition of  the Navier-Stokes
% resolvent for turbulent pipe flow
% Based on the turbulent pipe flow model proposed by McKeon & Sharma (2010)
% Written by Mitul Luhar on 02/06/2013

% After Fourier decomposition, u(r)exp(i*[k*x+n*theta-om*t]), the 
% Navier-Stokes equations for turbulent pipe flow are: 

% (-1i*om*M)x = Lx + Mf  --> x = (-1i*om*M - L)\M f

% Here x = [u;v;w;p], denotes the velocities and pressure
% L is a linear operator and f are the nonlinear 'forcing' terms. 
% M is a modified mass matrix.  The resolvent is: (-1i*om*M - L)\M

%INPUTS
% Re: Reynolds number based on pipe radius and 2x bulk-avg. velocity
% k : axial wave number (k > 0)
% n : azimuthal wave number (has to be an integer!)
% om: radian frequency scaled such that phase speed c = om/k is normalized 
% based on centerline velocity
% N : number of grid points in r:(0,1]
% nsvd: number of singular modes to compute

% varargin specifies the boundary condition

% varargin = {} - no slip

% varargin = {'OC',yPD,AD}: opposition control with detection at yPD from
% wall (in plus units), with amplitude AD, such that v(yPD) = -AD*v(0)

% varargin = {'compliant',freqRatio,dampRatio,massRatio}: compliant surface
% with frequency ratio, damping ratio and mass ratio as specified.  See
% pipeBCCompliantSHM.m for further detail

close all;

%% Load the mean velocity 

load(filename, 'w_mean_th_time');
W = w_mean_th_time;

% load('top_hat_ujet.mat'); %#ok<*LOAD>

% rc = r';
% W = top_hat_ujet';
%% Read the grid file 

fid = fopen('./x1_grid.in');  %% Reading the radial grid

D = cell2mat(textscan(fid, '%f%f', 'headerlines', 1));

rgrid = D(1:end-9,2);

for i = 1:size(rgrid,1)-2
    rc(i,1) = 0.5*(rgrid(i+1,1) + rgrid(i,1));  %#ok<*AGROW> % Centered the grid faces to grid centers
end
%% Coordinate system based on Chebyshev collocation
[r,dr,D1E,D1O,D2E,D2O] = pipeCoords(n,N,rc2,rmax);
% r: radial coordinate (0,1] stretched using formulation in Lesshaft and
% Huerre 2007
% dr: integration weights
% D1E,D1O:  Even and odd first difference matrices 
% D2E,D2O:  Even and odd second difference matrices

% NOTE: definition of even and odd changes with n   
% D1E/D2E correspond to the behavior of the axial velocity
% D1O/D2O correspond to the behavior of the radial/azimuthal velocity

%% Load velocity profile.
vel_data = [rc W];
U0 = spline(vel_data(:,1), vel_data(:,2), r); %% Just using the axial velocity condition for now
U0 = smoothdata(U0, 'gaussian');
plot(r, U0, 'ko');
% [U0,yP,UP]  = pipeVel(Re,1-r);
% U0: profile rescaled to match laminar (i.e. bulk average = 0.5)
% y = (1-r): distance from the wall, normalized by pipe radius
% UP, yP: velocity and y in plus units

% Calculate mean shear
D1R = mod(n+1,2)*D1E + mod(n,2)*D1O; % This is the 'true' even matrix
dU0 = diag(smoothdata(D1R*U0, 'gaussian')); % Shear must be smoothed as data can be noisy
dU0_ns = diag(D1R*U0); % Shear must be smoothed as data can be noisy
% NOTE: Need to create a better solution than 'smooth'
figure;
plot(r, diag(dU0), 'k-', 'Linewidth',2);
% hold on;
% plot(r, diag(dU0_ns), 'r-', 'Linewidth',2);
%% Calculate linear operator, L, and mass matrix, M
% M(dx/dt) = Lx + Mf 
[L, M] = pipeOperators(Re,k,n,r,D1O,D1E,D2O,D2E,U0,dU0);

%% Compute Resolvent
% Scale omega such that c = om/k scales with centerline velocity
omt = om;
% The governing equation reads: (-i*om*M - L)x = Mf
LHS = -1i*omt*M-L;
RHS = M; 

H = pipeBC(LHS,RHS,N,r,n); 

% Impose boundary conditions (BC) and calculate resolvent, H = (LHS/RHS)
% if(isempty(varargin))
%     % No slip
%     H = pipeBC(LHS,RHS,yP,N); 
% else
%     % User specified: opposition control (OC) or compliant wall (compliant)
%     switch varargin{1}
%         case 'OC'
%             H = pipeBC(LHS,RHS,yP,N,varargin{2},varargin{3});
%         case 'compliant'
%             H = pipeBCCompliantSHM(LHS,RHS,dU0,omt,varargin{2},varargin{3},varargin{4});
%         otherwise
%             error('myApp:argChk','Please specify appropriate boundary condition: OC or compliant')
%     end
% end


%% Get resolvent trapezoidal quadrature weights

nothetar = length(r);
weight_thetar = zeros(N,1);
weight_thetar(1) = pi*( r(1) + (r(2)-r(1))/2)^2 - pi*(r(1))^2;

for i=2:nothetar-1
        weight_thetar(i) = pi*( r(i) + (r(i+1)-r(i))/2 )^2 - pi*( r(i) - (r(i)-r(i-1))/2 )^2;
end

weight_thetar(nothetar) = pi*r(end)^2 - pi*( r(end) - (r(end)-r(end-1))/2 )^2;

%% Scale Resolvent
% Currently, the resolvent is scaled to yield unit L2 norm for the singular
% forcing and response modes.  Alternative norms may be considered.


b =  10^-20;

tanh_weight = 0.5*(1-b)*(1+tanh(Ld-r))+b;     % Check Noguiera et al. 2019

IWf  = sqrtm(diag(weight_thetar));            % Forcing weights
iIW  = eye(length(r))/IWf;
Z = zeros(length(r));
isqW = [iIW Z Z Z; Z iIW Z Z; Z Z iIW Z; Z Z Z Z];

IWr   = sqrtm(diag(tanh_weight.*weight_thetar));  % Response weights
sqW  = [ IWr Z Z Z; Z  IWr Z Z; Z Z IWr Z; Z Z Z Z];

% Weighted resolvent
HW = sqW*H*isqW;

%% Singular value decomposition
[suW, ssW, svW] = svds(HW,nsvd,'largest','MaxIterations',1000); 

iIW  = eye(length(r))/IWr;                   % Response weights
isqW = [iIW Z Z Z; Z iIW Z Z; Z Z iIW Z; Z Z Z Z];
su = isqW*suW; 

iIW  = eye(length(r))/IWf;                   % Forcing weights
isqW = [iIW Z Z Z; Z iIW Z Z; Z Z iIW Z; Z Z Z Z];
sv = isqW*svW;

ss = diag(ssW);
% ss: singular values
% su: singular response (velocity) modes
% sv: singular forcing modes

% set phase of first non-zero point based on critical layer
% if(om/k < 1)
%     ind = find((U0/max(U0))>(om/k),1,'first');
% else
%     ind = N;
% end
% phase_shift = -1i*angle(su(ind,:));
% sv = sv*diag(exp(phase_shift));

% Because of the l2 norm used to scale the resolvent, we do not have any
% pressure data.  Calculate pressure modes using the un-scaled resolvent.
% su = H*sv;
% su = su*diag(1./ss);

end