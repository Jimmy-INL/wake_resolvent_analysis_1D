%% Sheel Nidhan, 2020
%  Run script for the resolvent analysis of wake
%  Adapted from the code of Oliver T. Schmidt 2019 to perform resolvent analysis in 1D
%  All the portions of code pertaining to the sponges are removed for
%  current analysis

clear;
close all;
clc;

%% Setting the properties of graph

set(groot, 'defaultAxesTickLabelInterpreter','latex'); set(groot, 'defaultLegendInterpreter','latex');  set(groot, 'defaultTextInterpreter','latex'); 
set(groot, 'defaultFigureRenderer','painters')
set(groot, 'defaultFigureColor',[1 1 1])

%% Velocity profile 

filename = './ustreamwise/mean_velocity_x_D_30.mat';
Ld       = 1.91;
%% Independant coefficients

Re = 50000;
N  = 300;
rc2 = 2*Ld; rmax = 10;
nsvd = 3;
%% Setup for frequency

m = 1;

% kx
kx = linspace(2*pi*0.135, 2*pi*0.135, 1)';
% kx  = linspace(2*pi*0.135,2*pi*0.135,1)';

% St specification
St            = linspace(0, 20*0.027, 21)';
% St = 0.135;

SIGMA_vec       = St*2*pi;

%% Run resolvent for each case

SU = zeros(4*N,nsvd,size(St,1),size(kx,1));
SV = zeros(4*N,nsvd,size(St,1),size(kx,1));
SS = zeros(nsvd,size(St,1),size(kx,1));

for St_loop = 1:size(St,1)
    disp(St_loop);
    for kx_loop = 1:size(kx,1)
        om = SIGMA_vec(St_loop,1); k = kx(kx_loop,1);
        [r,su,ss,sv,U0,dU0,dr]  = resolventSVD(filename,Ld,Re,k,m,om,N,rc2,rmax,nsvd);
        SU(:,:,St_loop,kx_loop) = su;
        SV(:,:,St_loop,kx_loop) = sv;
        SS(:,St_loop,kx_loop)   = ss;
    end
end

%% Preliminary plots of gains

figure;
h1 = semilogy(St, squeeze(SS(1,:,1)), 'k-', 'Linewidth', 2);
hold on;
h2 = semilogy(St, squeeze(SS(2,:,1)), 'r-', 'Linewidth', 2);
h3 = semilogy(St, squeeze(SS(3,:,1)), 'b-', 'Linewidth', 2);

hXLabel = xlabel('$St$','interpreter','latex','fontsize',20);
hYLabel = ylabel('$Gain$','interpreter','latex','fontsize',20);

hLegend = legend([h1,h2,h3],'First mode','Second mode','Third mode');
hLegend.Interpreter = 'Latex';
hLegend.FontSize = 20;
hLegend.FontWeight = 'bold';
hLegend.Position = [0 0 1 1];

% set(gcf, 'PaperPositionMode', 'auto');
% print(gcf,'gain_m2_kx0.png','-dpng','-r300');  
% print(gcf,'gain_m2_kx0.eps','-depsc','-r600');

%% Preliminary plots of modes

figure;
hold on;
h1 = plot(r/Ld, abs(squeeze(SU(1:N, 1, 6))), 'k-', 'linewidth', 2);

figure;
hold on;
h1 = plot(r/Ld, abs(squeeze(SU(N+1:2*N, 1, 6))), 'r-', 'linewidth', 2); %#ok<*NASGU>

figure;
hold on
h1 = plot(r/Ld, abs(squeeze(SU(2*N+1:3*N, 1, 6))), 'b-', 'linewidth', 2);
