function out = implicitCtrlGenerateVHDL(object, circuit_parameters)
%IMPLICITCTRLGENERATEVHDL
% Generates VHDL code for implicit MPC controller placed within an embedded
% system (observer + controller)
% 
% This is a private method.

nx = object.getNumberOfStates;
np = object.getNumberOfParameters;
nu = object.getNumberOfInputs;
nd = object.getNumberOfUnmeasurableInputs;
ny = object.getNumberOfOutputs;
nxref = numel(object.getController.getTrackingVariable);

obs = object.getObserver;
ctrl = object.getController;

trackVar = ctrl.getTrackingVariable;
N = ctrl.getInformation.options.N;
Nu = ctrl.getInformation.options.Nu;

% System sampling time
sysSamplingTime = ctrl.getInformation.sys.getSamplingTime;

% Set default circuit parameters (the uninitialized ones)
circuit_parameters = embeddedSystemVHDLset(object, circuit_parameters);

% Read circuit_parameters structure

% Number of bits to represent input
nbit = circuit_parameters.inputResolution;

% Number of bits to represent output
nbitout = circuit_parameters.outputResolution;

% Number of bits to represent all the signals in the algorithm used to
% solve the otpimization problem
nbit_coeff = circuit_parameters.coeffResolution;
% Number of bits to represent the ingeter part of all the signals in the
% algorithm used to solve the optimization problem
nbitInt_coeff = circuit_parameters.coeffIntResolution;

% FPGA clock frequency
frequency = circuit_parameters.frequency;

% FPGA device for HLS synthesis
fpgaBoard = circuit_parameters.fpgaBoard;

% Folder for saving VHDL files
folder = circuit_parameters.folder;

% Range of signals to represent
range = circuit_parameters.range;

% Flag indicating if an interface must be generated
generateInterface = circuit_parameters.generateInterface;

% Circuit input range
inputRange = circuit_parameters.inputRange;

% Circuit output range
outputRange = circuit_parameters.outputRange;

% Number of ADMM iterations
maxIter = circuit_parameters.ADMMparameters.maxIter;

% Regularization parameter for ADMM
regPar = circuit_parameters.ADMMparameters.regPar;

% Compute matrices for algorithm initializations
% LTI system matrices
augSys = ctrl.getInformation.sys;
[A, ~, ~, ~, Ex, ~, Fx, ~, Gx, ~] = augSys.getMatrices;

if nxref ~= 0
    % x = [x; uOld];
    augSys = augSys.deltau();
    % LTI extended system matrices
    [A, ~, ~, ~, Ex, ~, Fx, ~, Gx, ~] = augSys.getMatrices;
end

% Compute matrices for ADMM algorithm
if ~ctrl.getInformation.options.tracking
    [QP1, QP2, ineqL, ineqR, eqL, eqR] = ctrl.computeQP(zeros(nx,1), zeros(np,1), zeros(nd,1), ctrl.getInformation.options.ref, "ADMM");
else
    [QP1, QP2, ineqL, ineqR, eqL, eqR] = ctrl.computeQP(zeros(nx,1), zeros(np,1), zeros(nd,1), zeros(nxref,1), "ADMM");
end
[M1, M2, M3, M4, v1, v2, v3] = ctrl.computeADMMmatrices(QP1, QP2, ineqL, ineqR, eqL, eqR, regPar);

% Get observer matrices
[Aobs, Bobs, Cobs, Dobs, Gxobs, Gyobs] = obs.getMatrices();

disp(['Destination folder for VHDL files: ', folder]);
disp('Generating VHDL files...');

% Create a new folder
if ~exist(folder,'dir')
    mkdir(folder)
    mkdir(strcat(folder, '/cpp'))
    mkdir(strcat(folder, '/vhdl'))
end

% Observer initial state
initialState = circuit_parameters.initialState;
initialState_bin = cell(nx,1);
for i=1:nx
    iscale = (initialState(i)-(range.xmax(i)+range.xmin(i))/2)*(circuit_parameters.outputRange.max(1)-circuit_parameters.outputRange.min(1))/(range.xmax(i)-range.xmin(i))+(circuit_parameters.outputRange.max(1)+circuit_parameters.outputRange.min(1))/2;
    if strcmp(circuit_parameters.outputRepresentation,'signed')
        numi = decimal2signed(fix(iscale),circuit_parameters.outputResolution,0);
    else
        numi = decimal2unsigned(fix(iscale),circuit_parameters.outputResolution,0);
    end
    initialState_bin{i} = numi.bin;
end

% Number of bits to represent the integer part of input
if nxref ~= 0
    nbitInt = ceil(log2(max(abs([range.pmax, range.pmin, range.ymax, range.ymin, range.xrefmax, range.xrefmin]),[],'all')));
else
    nbitInt = ceil(log2(max(abs([range.pmax, range.pmin, range.ymax, range.ymin]),[],'all')));
end
% Number of bits to represent the integer part of output
nbitIntOut = ceil(log2(max(abs([range.umax, range.umin]),[],'all')));
nbitIntOut_predState = ceil(log2(max(abs([range.xmax, range.xmin, range.dmax, range.dmin]),[],'all')));

% Default control value and its binary representation
do = circuit_parameters.defaultOutput;
do_bin = cell(nu,1);
if circuit_parameters.useDAC == 1
    for i=1:nu
        dscale = (do(i)-(range.umax(i)+range.umin(i))/2)*(outputRange.max(i)-outputRange.min(i))/(range.umax(i)-range.umin(i))+(outputRange.max(i)+outputRange.min(i))/2;
        if strcmp(circuit_parameters.outputRepresentation,'signed')
            numi = decimal2signed(fix(dscale),nbitout,0);
        else
            numi = decimal2unsigned(fix(dscale),nbitout,0);
        end
        do_bin{i} = numi.bin;
    end
else
    for i=1:nu
        if strcmp(circuit_parameters.outputRepresentation,'signed')
            numi = decimal2signed(do,nbitout,nbitout-nbitIntOut-1);
        else
            numi = decimal2unsigned(do,nbitout,nbitout-nbitIntOut);
        end
        do_bin{i} = numi.bin;
    end
end

% Compute arrays to transform the parameters from their actual (model)
% range to the circuit range: p_cir = sim_p_scale_gain.*p + sim_p_scale_bias
if np == 0
    sim_p_scale_gain = [];
    sim_p_scale_bias = [];
else
sim_p_scale_gain = (circuit_parameters.inputRange.max(1:np)-circuit_parameters.inputRange.min(1:np))./...
    (range.pmax(:)-range.pmin(:));
sim_p_scale_bias = (range.pmax+range.pmin)/2-...
    ((circuit_parameters.inputRange.max(1:np)+circuit_parameters.inputRange.min(1:np))/2./sim_p_scale_gain)';
end

% Compute arrays to transform the system outputs from their circuit range
% to the actual (model) range: y_cir = sim_y_scale_gain.*y + sim_y_scale_bias
sim_y_scale_gain = (circuit_parameters.inputRange.max(np+1:np+ny)-circuit_parameters.inputRange.min(np+1:np+ny))./...
    (range.ymax(:)-range.ymin(:));
sim_y_scale_bias = (range.ymax+range.ymin)/2-...
    ((circuit_parameters.inputRange.max(np+1:np+ny)+circuit_parameters.inputRange.min(np+1:np+ny))/2./sim_y_scale_gain)';

% Compute arrays to transform the estimated circuit states from their
% actual (model) range to the circuit range:
% x = (x_cir - sim_x_scale_bias)./sim_x_scale_gain
sim_x_scale_gain = (range.xmax(:)-range.xmin(:))./(circuit_parameters.outputRange.max(1)-circuit_parameters.outputRange.min(1));
sim_x_scale_bias = (range.xmax+range.xmin)/2-...
    ((circuit_parameters.outputRange.max(1)+circuit_parameters.outputRange.min(1))/2.*sim_x_scale_gain)';

% Compute arrays to transform the unmeasurable inputs from their actual
% (model) range to the circuit range:
% d_cir = sim_d_scale_gain.*d + sim_d_scale_bias
if nd == 0
    sim_d_scale_gain = [];
    sim_d_scale_bias = [];
else
    sim_d_scale_gain = (range.dmax(:)-range.dmin(:))./(circuit_parameters.outputRange.max(1)-circuit_parameters.outputRange.min(1));
    sim_d_scale_bias = (range.dmax+range.dmin)/2-...
        ((circuit_parameters.outputRange.max(1)+circuit_parameters.outputRange.min(1))/2.*sim_d_scale_gain)';
end

% Compute arrays to transform the outputs from their circuit range to the
% actual (model) range: u = (u_cir - sim_u_scale_bias)./sim_u_scale_gain
sim_u_scale_gain = (range.umax(:)-range.umin(:))./(circuit_parameters.outputRange.max(:)-circuit_parameters.outputRange.min(:));
sim_u_scale_bias = (range.umax+range.umin)/2-...
    ((circuit_parameters.outputRange.max(:)+circuit_parameters.outputRange.min(:))/2.*sim_u_scale_gain)';

% Compute arrays to transform the reference signals from their actual
% (model) range to the circuit range: xref_cir = sim_xref_scale_gain.*xref + sim_xref_scale_bias
if nxref == 0
    sim_xref_scale_gain = 0;
    sim_xref_scale_bias = 0;
else
    sim_xref_scale_gain = (circuit_parameters.inputRange.max(np+ny+1:np+ny+nxref)-circuit_parameters.inputRange.min(np+ny+1:np+ny+nxref))./...
        (range.xrefmax(:)-range.xrefmin(:));
    sim_xref_scale_bias = (range.xrefmax(:)+range.xrefmin(:))/2-...
        ((circuit_parameters.inputRange.max(np+ny+1:np+ny+nxref)+circuit_parameters.inputRange.min(np+ny+1:np+ny+nxref))/2./sim_xref_scale_gain);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%% GENERATE embeddedSystem.H FILE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Open the header file
f = fopen([folder,'/cpp/embeddedSystem.h'],'w');

fprintf(f,'#ifndef _EMBEDDEDSYSTEM_H_\n');
fprintf(f,'#define _EMBEDDEDSYSTEM_H_\n\n');

fprintf(f,'// Library for fixed point number representation\n');
fprintf(f,'#include <ap_fixed.h>\n\n');

fprintf(f,'// Fixed point data representation for the circuit input\n');
if strcmp(circuit_parameters.inputRepresentation,'signed')
    if circuit_parameters.useADC == 1
        fprintf(f,'typedef ap_fixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_in;\n\n', nbit, nbit);
    else
        fprintf(f,'typedef ap_fixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_in;\n\n', nbit, nbitInt+1);
    end
else
    if circuit_parameters.useADC == 1
        fprintf(f,'typedef ap_ufixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_in;\n\n', nbit, nbit);
    else
        fprintf(f,'typedef ap_ufixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_in;\n\n', nbit, nbitInt);
    end
end

fprintf(f,'// Fixed point data representation for the circuit output\n');
if strcmp(circuit_parameters.outputRepresentation,'signed')
    if circuit_parameters.useDAC == 1
        fprintf(f,'typedef ap_fixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_out;\n\n', nbitout, nbitout);
        fprintf(f,'typedef ap_fixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_out_state;\n\n', nbitout, nbitout);
    else
        fprintf(f,'typedef ap_fixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_out;\n\n', nbitout, nbitIntOut+1);
        fprintf(f,'typedef ap_fixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_out_state;\n\n', nbitout, nbitIntOut_predState+1);
    end
else
    if circuit_parameters.useDAC == 1
        fprintf(f,'typedef ap_ufixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_out;\n\n', nbitout, nbitout);
        fprintf(f,'typedef ap_ufixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_out_state;\n\n', nbitout, nbitout);
    else
        fprintf(f,'typedef ap_ufixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_out;\n\n', nbitout, nbitIntOut);
        fprintf(f,'typedef ap_ufixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_out_state;\n\n', nbitout, nbitIntOut_predState);
    end
end

fprintf(f,'// Fixed point data representation for the data to convert input\n');
fprintf(f,'// from ADC range to actual (model range) and from actual range\n');
fprintf(f,'// to DAC range\n');
if circuit_parameters.useADC == 1 || circuit_parameters.useDAC == 1
        nbitInt_scale = ceil(log2(max(abs([1./sim_p_scale_gain; 1./sim_y_scale_gain; 1./sim_x_scale_gain; 1./sim_d_scale_gain; 1./sim_u_scale_gain]),[],'all')));
        nbitInt_conv = max([nbit, nbitout, nbitInt_scale])+1;
%         fprintf(f,'typedef ap_fixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_conv;\n\n', 2*nbitInt_conv, nbitInt_conv);
%         fprintf(f,'typedef ap_fixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_conv;\n\n', 32, nbitInt_conv);
        fprintf(f,'typedef ap_fixed<%d, %d, AP_RND_CONV, AP_SAT> fxd_conv;\n\n', nbit_coeff+nbitInt_conv, nbitInt_conv);
end

fprintf(f,'// Fixed point data representation for every signal inside the algorithm\n');
fprintf(f,'typedef ap_fixed<%d, %d> fxd;\n\n', nbit_coeff, nbitInt_coeff);

nbitInt_m_scale = ceil(log2(max([max(abs(M1),[],'all'), max(abs(M2),[],'all'), max(abs(M3),[],'all'), max(abs(M4),[],'all')],[],'all')));
nbitInt_m = max(nbitInt_m_scale)+2;
fprintf(f,'typedef ap_fixed<%d, %d> fxd_m;\n\n', nbit_coeff+2, nbitInt_m);

fprintf(f,'typedef ap_fixed<%d, %d> fxd_tmp_m;\n\n', 2*nbit_coeff + nbitInt_m + 2, nbitInt_coeff + nbitInt_m + 2);

nCon = numel(v3);
if nxref == 0
    nDim = Nu*nu + (N+1)*nx;
else
    nDim = Nu*nu + (N+1)*(nx+nu);
end

nbitInt_p_scale = ceil(log2(max(abs([Aobs, Bobs, Gxobs]),[],'all')));
nbitInt_p = max(nbitInt_p_scale)+2;
fprintf(f,'typedef ap_fixed<%d, %d> fxd_p;\n\n', nbit_coeff, nbitInt_p);
fprintf(f,'typedef ap_fixed<%d, %d> fxd_tmp_p;\n\n', nbit_coeff, nbitInt);

fprintf(f,'// Number of system states (x_k)\n');
fprintf(f,'#define nX %d\n\n',nx);

fprintf(f,'// Number of system inputs (u_k)\n');
fprintf(f,'#define nU %d\n\n',nu);

fprintf(f,'// Number of system parameters (p_k)\n');
fprintf(f,'#define nP %d\n\n',np);

fprintf(f,'// Number of system outputs (y_k)\n');
fprintf(f,'#define nY %d\n\n',ny);

fprintf(f,'// Number of system unmeasurable inputs (d_k)\n');
fprintf(f,'#define nD %d\n\n',nd);

fprintf(f,'// Number of observer outputs ([x_k; d_k])\n');
fprintf(f,'#define nX_OBS %d\n\n',nx+nd);

fprintf(f,'// Prediction horizon\n');
fprintf(f,'#define N %d\n\n',N);

fprintf(f,'// Control horizon\n');
fprintf(f,'#define Nu %d\n\n',Nu);

if nxref == 0
    fprintf(f,'// Number of controller inputs [x_k]\n');
    fprintf(f,'#define nX_CTRL %d\n\n',nx);
else
    fprintf(f,'// Number of reference inputs\n');
    fprintf(f,'#define nRef %d\n\n',nxref);
    fprintf(f,'// Number of controller inputs [x_k; u_(k-1)]\n');
    fprintf(f,'#define nX_CTRL %d\n\n',nx+nu);
end

fprintf(f,'// Number of optimization variables\n');
fprintf(f,'#define nDim_CTRL %d\n\n', nDim);

fprintf(f,'// Number of constraints\n');
fprintf(f,'#define nCon %d\n\n', nCon);

fprintf(f,'// Regularization parameter\n');
fprintf(f,'#define reg_par %d\n\n',regPar);

fprintf(f,'// Maximum number of iterations\n');
fprintf(f,'#define max_iter %d\n\n',maxIter);

Fpred = [Aobs, Bobs];
fprintf(f,'// Precomputed matrix for state prediction\n');
fprintf(f,'static const fxd_p Fpred[nX_OBS][nX_OBS+nU+nP+nY] = {\n');
for i=1:nx+nd-1
    fprintf(f,'{%f',Fpred(i,1));
    for j=2:nx+nd+nu+np+ny
        fprintf(f,', ');
        fprintf(f,'%f',Fpred(i,j));
    end
    fprintf(f,'},\n');
end
fprintf(f,'{%f',Fpred(nx+nd,1));
for j=2:nx+nd+nu+np+ny
    fprintf(f,', ');
    fprintf(f,'%f',Fpred(nx+nd,j));
end
fprintf(f,'} };\n\n');

Gpred = Gxobs;
fprintf(f,'// Precomputed matrix for state prediction\n');
fprintf(f,'static const fxd_p Gpred[nX_OBS] = {');
for i=1:nx+nd-1
    fprintf(f,'%f, ',Gpred(i));
end
fprintf(f,'%f};\n\n',Gpred(nx+nd));

if isa(obs, 'kalmanFilter')
    Cobs = Cobs(ny+1:end,:);
    Dobs = Dobs(ny+1:end,:);
    Gyobs = Gyobs(ny+1:end,:);

    Fupdate = [Cobs Dobs];
    fprintf(f,'// Precomputed matrix for state prediction\n');
    fprintf(f,'static const fxd Fupdate[nX_OBS][nX_OBS+nU+nP+nY] = {{');
    for i=1:nx+nd-1
        for j=1:nx+nd+nu+np+ny-1
            fprintf(f,'%f,',Fupdate(i,j));
        end
        fprintf(f,'%f},\n{',Fupdate(i,end));
    end
    for j=1:nx+nd+nu+np+ny-1
        fprintf(f,'%f,',Fupdate(end,j));
    end
    fprintf(f,'%f}};\n\n',Fupdate(end,end));

    fprintf(f,'// Precomputed matrix for state prediction\n');
    fprintf(f,'static const fxd Gupdate[nX_OBS] = {');
    for i=1:nx+nd-1
        fprintf(f,'%f,\n',Gyobs(i));
    end
    fprintf(f,'%f};\n\n',Gyobs(end));
end

fprintf(f,'// Initial observer state\n');
fprintf(f,'static fxd initial_state[nX_OBS] = {');
for i=1:nx-1
    fprintf(f,'%f, ',initialState(i));
end
if nd ~= 0
    fprintf(f,'%f, ',initialState(nx+nd));
    for i=1:nd-1
        fprintf(f,'0, ');
    end
    fprintf(f,'0};\n\n');
else
    fprintf(f,'%f};\n\n',initialState(nx+nd));
end

if nxref ~= 0
    fprintf(f,'// Index of the input to be tracked\n');
    fprintf(f,'static const fxd ref_idx[nRef] = {');
    for i=1:nxref-1
        fprintf(f,'%d, ', fix(trackVar(i)-1));
    end
    fprintf(f,'%d};\n\n', fix(trackVar(nxref)-1));
end

% fprintf(f,'// Precomputed matrix for ADMM initialization\n');
% if nxref ~= 0
%     Apwr = [];
%     for i=1:N
%        Apwr = [Apwr; A^i];
%     end
%     fprintf(f,'static const fxd A_pwr[(N+1)*nX_CTRL][nX_CTRL] = {\n');
%     for i=1:(N+1)*(nx+nu)-1
%         fprintf(f,'{%f',Apwr(i,1));
%         for j=2:nx+nu
%             fprintf(f,', ');
%             fprintf(f,'%f',Apwr(i,j));
%         end
%         fprintf(f,'},\n');
%     end
%     fprintf(f,'{%f',Apwr((N+1)*(nx+nu),1));
%     for j=2:nx+nu
%         fprintf(f,', ');
%         fprintf(f,'%f',Apwr((N+1)*(nx+nu),j));
%     end
% else
%     Apwr = [];
%     for i=1:N
%        Apwr = [Apwr; A^i];
%     end
%     fprintf(f,'static const fxd A_pwr[(N+1)*nX_CTRL][nX_CTRL] = {\n');
%     for i=1:(N+1)*nx-1
%         fprintf(f,'{%f',Apwr(i,1));
%         for j=2:nx
%             fprintf(f,', ');
%             fprintf(f,'%f',Apwr(i,j));
%         end
%         fprintf(f,'},\n');
%     end
%     fprintf(f,'{%f',Apwr((N+1)*(nx),1));
%     for j=2:nx
%         fprintf(f,', ');
%         fprintf(f,'%f',Apwr((N+1)*(nx),j));
%     end
% end
% fprintf(f,'} };\n\n');

if np ~= 0
    fprintf(f,'// Precomputed matrix for ADMM initialization\n');
    fprintf(f,'static const fxd E[nX_CTRL][nP] = {\n');
    if nxref ~= 0
        for i=1:nx+nu-1
          fprintf(f,'{%f', Ex(i,1));
          for j=2:np
              fprintf(f,', ');
              fprintf(f,'%f', Ex(i,j));
          end
          fprintf(f,'},\n');
        end
        fprintf(f,'{%f', Ex(nx+nu,1));
        for j=2:np
            fprintf(f,', ');
            fprintf(f,'%f', Ex(nx+nu,j));
        end
    else
        for i=1:nx-1
          fprintf(f,'{%f', Ex(i,1));
          for j=2:np
              fprintf(f,', ');
              fprintf(f,'%f', Ex(i,j));
          end
          fprintf(f,'},\n');
        end
        fprintf(f,'{%f', Ex(nx,1));
        for j=2:np
            fprintf(f,', ');
            fprintf(f,'%f', Ex(nx,j));
        end
    end
    fprintf(f,'} };\n\n');
end

if nd ~= 0
    fprintf(f,'// Precomputed matrix for ADMM initialization\n');
    fprintf(f,'static const fxd F[nX_CTRL][nD] = {\n');
    if nxref ~= 0
        for i=1:nx+nu-1
          fprintf(f,'{%f', Fx(i,1));
          for j=2:nd
              fprintf(f,', ');
              fprintf(f,'%f', Fx(i,j));
          end
          fprintf(f,'},\n');
        end
        fprintf(f,'{%f', Fx(nx+nu,1));
        for j=2:np
            fprintf(f,', ');
            fprintf(f,'%f', Fx(nx+nu,j));
        end
    else
        for i=1:nx-1
          fprintf(f,'{%f', Fx(i,1));
          for j=2:nd
              fprintf(f,', ');
              fprintf(f,'%f', Fx(i,j));
          end
          fprintf(f,'},\n');
        end
        fprintf(f,'{%f', Fx(nx,1));
        for j=2:np
            fprintf(f,', ');
            fprintf(f,'%f', Fx(nx,j));
        end
    end
    fprintf(f,'} };\n\n');
end

fprintf(f,'// Precomputed matrix for ADMM initialization\n');
if nxref ~= 0
    fprintf(f,'static const fxd G[nX_CTRL] = {');
    for i=1:nx+nu-1
        fprintf(f,'%f, ', Gx(i));
    end
    fprintf(f,'%f};\n\n', Gx(nx+nu));
else
    fprintf(f,'static const fxd G[nX_CTRL] = {');
    for i=1:nx-1
        fprintf(f,'%f, ', Gx(i));
    end
    fprintf(f,'%f};\n\n', Gx(nx));
end

fprintf(f,'// Precomputed matrix for ADMM\n');
fprintf(f,'static const fxd_m M1[nDim_CTRL][nDim_CTRL] = {\n');
for i=1:nDim-1
    fprintf(f,'{%f',M1(i,1));
    for j=2:nDim
        fprintf(f,', ');
        fprintf(f,'%f',M1(i,j));
    end
    fprintf(f,'},\n');
end
fprintf(f,'{%f',M1(nDim,1));
for j=2:nDim
    fprintf(f,', ');
    fprintf(f,'%f',M1(nDim,j));
end
fprintf(f,'} };\n\n');

fprintf(f,'// Precomputed matrix for ADMM\n');
fprintf(f,'static const fxd_m M2[nDim_CTRL][nCon + (N+1)*nX_CTRL] = {\n');
if nxref ~= 0
    for i=1:nDim-1
        fprintf(f,'{%f',M2(i,1));
        for j=2:nCon + (N+1)*(nx+nu)
            fprintf(f,', ');
            fprintf(f,'%f',M2(i,j));
        end
        fprintf(f,'},\n');
    end
    fprintf(f,'{%f',M2(nDim,1));
    for j=2:nCon + (N+1)*(nx+nu)
        fprintf(f,', ');
        fprintf(f,'%f',M2(nDim,j));
    end
else
    for i=1:nDim-1
        fprintf(f,'{%f',M2(i,1));
        for j=2:nCon + (N+1)*nx
            fprintf(f,', ');
            fprintf(f,'%f',M2(i,j));
        end
        fprintf(f,'},\n');
    end
    fprintf(f,'{%f',M2(nDim,1));
    for j=2:nCon + (N+1)*nx
        fprintf(f,', ');
        fprintf(f,'%f',M2(nDim,j));
    end
end
fprintf(f,'} };\n\n');

fprintf(f,'// Precomputed matrix for ADMM\n');
fprintf(f,'static const fxd_m M3[nCon][nDim_CTRL] = {\n');
for i=1:nCon-1
    fprintf(f,'{%f',M3(i,1));
    for j=2:nDim
        fprintf(f,', ');
        fprintf(f,'%f',M3(i,j));
    end
    fprintf(f,'},\n');
end
fprintf(f,'{%f',M3(nCon,1));
for j=2:nDim
    fprintf(f,', ');
    fprintf(f,'%f',M3(nCon,j));
end
fprintf(f,'} };\n\n');

fprintf(f,'// Precomputed matrix for ADMM\n');
fprintf(f,'static const fxd_m M4[nCon + (N+1)*nX_CTRL][nDim_CTRL] = {\n');
if nxref ~= 0
    for i=1:nCon + (N+1)*(nx+nu) -1
        fprintf(f,'{%f',M4(i,1));
        for j=2:nDim
            fprintf(f,', ');
            fprintf(f,'%f',M4(i,j));
        end
        fprintf(f,'},\n');
    end
    fprintf(f,'{%f',M4(nCon + (N+1)*(nx+nu),1));
    for j=2:nDim
        fprintf(f,', ');
        fprintf(f,'%f',M4(nCon + (N+1)*(nx+nu),j));
    end
else
    for i=1:nCon + (N+1)*nx -1
        fprintf(f,'{%f',M4(i,1));
        for j=2:nDim
            fprintf(f,', ');
            fprintf(f,'%f',M4(i,j));
        end
        fprintf(f,'},\n');
    end
    fprintf(f,'{%f',M4(nCon + (N+1)*nx,1));
    for j=2:nDim
        fprintf(f,', ');
        fprintf(f,'%f',M4(nCon + (N+1)*nx,j));
    end
end
fprintf(f,'} };\n\n');

fprintf(f,'// Precomputed vector for ADMM\n');
fprintf(f,'static const fxd v3[nCon] = {');
for i=1:nCon - 1
    fprintf(f,'%f, ', v3(i));
end
fprintf(f,'%f};\n\n', v3(nCon));


if nxref ~= 0
    fprintf(f,'// Weight matrix for the state vector in the optimization\n');
    fprintf(f,'// problem (useful when the reference value changes)\n');
    Q = zeros(nx+nu);
    Q(1:nx,1:nx) = ctrl.getInformation.options.Q;
    fprintf(f,'static const fxd Q[nX_CTRL][nX_CTRL] = {');
    for i=1:nx+nu-1
        fprintf(f,'{%f',Q(i,1));
        for j=2:nx+nu
            fprintf(f,', ');
            fprintf(f,'%f',Q(i,j));
        end
    fprintf(f,'},\n');
    end
    fprintf(f,'{%f',Q(nx+nu,1));
    for j=2:nx+nu
        fprintf(f,', ');
        fprintf(f,'%f',Q(nx+nu,j));
    end
    fprintf(f,'} };\n\n');
        
    fprintf(f,'// Weight matrix for the state vector in the optimization\n');
    fprintf(f,'// problem (useful when the reference value changes)\n');
    P = zeros(nx+nu);
    P(1:nx,1:nx) = ctrl.getInformation.options.P;
    fprintf(f,'static const fxd P[nX_CTRL][nX_CTRL] = {');
    for i=1:nx+nu-1
        fprintf(f,'{%f',P(i,1));
        for j=2:nx+nu
            fprintf(f,', ');
            fprintf(f,'%f',P(i,j));
        end
    fprintf(f,'},\n');
    end
    fprintf(f,'{%f',P(nx+nu,1));
    for j=2:nx+nu
        fprintf(f,', ');
        fprintf(f,'%f',P(nx+nu,j));
    end
    fprintf(f,'} };\n\n');
else
    fprintf(f,'static const fxd q[nDim_CTRL] = {');
    for i=1:nDim-1
        fprintf(f,'%f, ',QP2(i));
    end
    fprintf(f,'%f};\n\n',QP2(nDim));
end

fprintf(f,'// Default control\n');
fprintf(f,'static const fxd default_u[nU] = {');
for i=1:nu - 1
        fprintf(f,'%f, ',do(i));
%     fprintf(f,'%f, ',0);
end
    fprintf(f,'%f};\n\n',do(nu));
% fprintf(f,'%f};\n\n',0);

if circuit_parameters.useADC == 1 || circuit_parameters.useDAC == 1
    fprintf(f,'// Arrays to transform the inputs from their circuit range\n');
    fprintf(f,'// to the actual (model) range:\n');
    fprintf(f,'// y = (y_cir - sim_y_scale_bias).*sim_y_scale_gain\n');
    fprintf(f,'static const fxd_conv sim_y_scale_bias[nY] = {');
    for i=1:ny-1
        fprintf(f,'%f, ',sim_y_scale_bias(i));
    end
    fprintf(f,'%f};\n',sim_y_scale_bias(ny));

    fprintf(f,'static const fxd_conv sim_y_scale_gain[nY] = {');
    for i=1:ny-1
        fprintf(f,'%f, ',1/sim_y_scale_gain(i));
    end
    fprintf(f,'%f};\n\n',1/sim_y_scale_gain(ny));

    fprintf(f,'// Arrays to transform the outputs from their actual (model)\n');
    fprintf(f,'// range to the actual circuit range:\n');
    fprintf(f,'// u_cir = u.*sim_u_scale_gain + sim_u_scale_bias\n');
    fprintf(f,'static const fxd_conv sim_u_scale_bias[nU] = {');
    for i=1:nu-1
        fprintf(f,'%f, ',sim_u_scale_bias(i));
    end
    fprintf(f,'%f};\n',sim_u_scale_bias(nu));

    fprintf(f,'static const fxd_conv sim_u_scale_gain[nU] = {');
    for i=1:nu-1
        fprintf(f,'%f, ',1/sim_u_scale_gain(i));
    end
    fprintf(f,'%f};\n\n',1/sim_u_scale_gain(nu));

    if np~=0
        fprintf(f,'// Arrays to transform the system parameters from\n');
        fprintf(f,'// their circuit range to the actual (model) range:\n');
        fprintf(f,'// p = (p_cir - sim_p_scale_bias).*sim_p_scale_gain\n');
        fprintf(f,'static const fxd_conv sim_p_scale_bias[nP] = {');
        for i=1:np-1
            fprintf(f,'%f, ',sim_p_scale_bias(i));
        end
        fprintf(f,'%f};\n',sim_p_scale_bias(np));

        fprintf(f,'static const fxd_conv sim_p_scale_gain[nP] = {');
        for i=1:np-1
            fprintf(f,'%f, ',1/sim_p_scale_gain(i));
        end
        fprintf(f,'%f};\n\n',1/sim_p_scale_gain(np));
    end

    fprintf(f,'// Arrays to transform the estimated states from\n');
    fprintf(f,'// their actual (model) range to the actual circuit range:\n');
    fprintf(f,'// x_cir = x.*sim_x_scale_gain + sim_x_scale_bias\n');
    fprintf(f,'static const fxd_conv sim_x_scale_bias[nX] = {');
    for i=1:nx-1
        fprintf(f,'%f, ',sim_x_scale_bias(i));
    end
    fprintf(f,'%f};\n',sim_x_scale_bias(nx));

    fprintf(f,'static const fxd_conv sim_x_scale_gain[nX] = {');
    for i=1:nx-1
        fprintf(f,'%f, ',1/sim_x_scale_gain(i));
    end
    fprintf(f,'%f};\n\n',1/sim_x_scale_gain(nx));

    if nd~=0
        fprintf(f,'// Arrays to transform the estimated disturbances from\n');
        fprintf(f,'// their actual (model) range to the actual circuit range:\n');
        fprintf(f,'// d_cir = d.*sim_d_scale_gain + sim_d_scale_bias\n');
        fprintf(f,'static const fxd_conv sim_d_scale_bias[nD] = {');
        for i=1:nd-1
            fprintf(f,'%f, ',sim_d_scale_bias(i));
        end
        fprintf(f,'%f};\n',sim_d_scale_bias(nd));

        fprintf(f,'static const fxd_conv sim_d_scale_gain[nD] = {');
        for i=1:nd-1
            fprintf(f,'%f, ',1/sim_d_scale_gain(i));
        end
        fprintf(f,'%f};\n\n',1/sim_d_scale_gain(nd));
    end

    if nxref~=0
        fprintf(f,'// Arrays to transform the reference signals from\n');
        fprintf(f,'// their circuit range to the actual (model) range:\n');
        fprintf(f,'// xref = (xref_cir - sim_xref_scale_bias).*sim_xref_scale_gain\n');
        fprintf(f,'static const fxd_conv sim_xref_scale_bias[nRef] = {');
        for i=1:nxref-1
            fprintf(f,'%f, ',sim_xref_scale_bias(i));
        end
        fprintf(f,'%f};\n',sim_xref_scale_bias(nxref));

        fprintf(f,'static const fxd_conv sim_xref_scale_gain[nRef] = {');
        for i=1:nxref-1
            fprintf(f,'%f, ',1/sim_xref_scale_gain(i));
        end
        fprintf(f,'%f};\n\n',1/sim_xref_scale_gain(nxref));
    end
end

if circuit_parameters.useADC == 1
    fprintf(f,'void scaleY(fxd_in y_in[nY], fxd y_reg[nY]);\n');
    if np ~= 0
        fprintf(f,'void scaleP(fxd_in p_in[nP], fxd p_reg[nP]);\n');
    end
    if nxref ~= 0
        fprintf(f,'void scaleRef(fxd_in ref_in[nRef], fxd ref_reg[nX]);\n');
    end
end

if circuit_parameters.useDAC == 1
    fprintf(f,'void scaleU(fxd u_reg[nU], fxd_out u_opt[nU]);\n');
    fprintf(f,'void scaleXout(fxd x_reg[nX], fxd_out_state x_est[nX]);\n');
    if nd ~= 0
        fprintf(f,'void scaleDout(fxd d_reg[nD], fxd_out_state d_est[nD]);\n');
    end
end

if np ~= 0
    fprintf(f,'void predictor(fxd y[nY], fxd p[nP], fxd u_old[nU], fxd currentState[nX_OBS]);\n\n');
else
    fprintf(f,'void predictor(fxd y[nY], fxd u_old[nU], fxd currentState[nX_OBS]);\n\n');
end

if isa(obs, 'kalmanFilter')
    if np ~= 0
        fprintf(f,'void corrector(fxd y[nY], fxd p[nP], fxd u_old[nU], fxd currentState[nX_OBS]);\n\n');
    else
        fprintf(f,'void corrector(fxd y[nY], fxd u_old[nU], fxd currentState[nX_OBS]);\n\n');
    end
end

if nxref ~= 0
    fprintf(f,'void augmentState(fxd x_reg[nX], fxd ref_reg[nX], fxd x_aug[nX_CTRL], fxd ref_aug[nX_CTRL], fxd u_old[nU]);\n');
    fprintf(f,'void extractU(fxd z[nDim_CTRL], fxd u_reg[nU], fxd u_old[nU]);\n');
    if np ~= 0 && nd ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in p_in[nP], fxd_in ref_in[nRef], fxd_out u_opt[nU], fxd_out_state x_est[nX], fxd_out_state d_est[nD]);\n\n');
        fprintf(f,'void admmInit(fxd x[nX_CTRL], fxd p[nP], fxd d[nD], fxd ref[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL]);\n');
    elseif np ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in p_in[nP], fxd_in ref_in[nRef], fxd_out u_opt[nU], fxd_out_state x_est[nX]);\n\n');
        fprintf(f,'void admmInit(fxd x[nX_CTRL], fxd p[nP], fxd ref[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL]);\n');
    elseif nd ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in ref_in[nRef], fxd_out u_opt[nU], fxd_out_state x_est[nX], fxd_out_state d_est[nD]);\n\n');
        fprintf(f,'void admmInit(fxd x[nX_CTRL], fxd d[nD], fxd ref[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL]);\n');
    else
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in ref_in[nRef], fxd_out u_opt[nU], fxd_out_state x_est[nX]);\n\n');
        fprintf(f,'void admmInit(fxd x[nX_CTRL], fxd ref[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL]);\n');
    end
else
    if np ~= 0 && nd ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in p_in[nP], fxd_out u_opt[nU], fxd_out_state x_est[nX], fxd_out_state d_est[nD]);\n\n');
        fprintf(f,'void admmInit(fxd x[nX_CTRL], fxd p[nP], fxd d[nD], fxd ref[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL]);\n');
    elseif np ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in p_in[nP], fxd_out u_opt[nU], fxd_out_state x_est[nX]);\n\n');
        fprintf(f,'void admmInit(fxd x[nX_CTRL], fxd p[nP], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL]);\n');
    elseif nd ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_out u_opt[nU], fxd_out_state x_est[nX], fxd_out_state d_est[nD]);\n\n');
        fprintf(f,'void admmInit(fxd x[nX_CTRL], fxd d[nD], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL]);\n');
    else
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_out u_opt[nU], fxd_out_state x_est[nX]);\n\n');
        fprintf(f,'void admmInit(fxd x[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL]);\n');
    end
end
fprintf(f,'void admm(fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL], fxd z[nDim_CTRL]);\n');

fprintf(f,'#endif\n');

% Close the header file
fclose(f);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%% GENERATE EMBEDDEDSYSTEM.CPP FILE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Open the main file
f = fopen([folder,'/cpp/embeddedSystem.cpp'],'w');

fprintf(f,'#include "embeddedSystem.h"\n\n');

if nxref ~= 0
    if np ~= 0 && nd ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in p_in[nP], fxd_in ref_in[nRef], fxd_out u_opt[nU], fxd_out_state x_est[nX], fxd_out_state d_est[nD])\n{\n');
    elseif np ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in p_in[nP], fxd_in ref_in[nRef], fxd_out u_opt[nU], fxd_out_state x_est[nX])\n{\n');
    elseif nd ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in ref_in[nRef], fxd_out u_opt[nU], fxd_out_state x_est[nX], fxd_out_state d_est[nD])\n{\n');
    else
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in ref_in[nRef], fxd_out u_opt[nU], fxd_out_state x_est[nX])\n{\n');
    end
else
    if np ~= 0 && nd ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in p_in[nP], fxd_out u_opt[nU], fxd_out_state x_est[nX], fxd_out_state d_est[nD])\n{\n');
    elseif np ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_in p_in[nP], fxd_out u_opt[nU], fxd_out_state x_est[nX])\n{\n');
    elseif nd ~= 0
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_out u_opt[nU], fxd_out_state x_est[nX], fxd_out_state d_est[nD])\n{\n');
    else
        fprintf(f,'void embeddedSystem(bool ctrl_start, fxd_in y_in[nY], fxd_out u_opt[nU], fxd_out_state x_est[nX])\n{\n');
    end
end

fprintf(f,'#pragma HLS ARRAY_PARTITION variable=y_in dim=1 complete\n');
if np ~= 0
    fprintf(f,'#pragma HLS ARRAY_PARTITION variable=p_in dim=1 complete\n');
end
if nxref ~= 0
    fprintf(f,'#pragma HLS ARRAY_PARTITION variable=ref_in dim=1 complete\n');
end
fprintf(f,'#pragma HLS ARRAY_PARTITION variable=u_opt dim=1 complete\n\n');
fprintf(f,'#pragma HLS ARRAY_PARTITION variable=x_est dim=1 complete\n\n');
if nd ~= 0
    fprintf(f,'#pragma HLS ARRAY_PARTITION variable=d_est dim=1 complete\n');
end

fprintf(f,'static fxd currentState[nX_OBS];\n\n');

fprintf(f,'fxd y_reg[nY];\n\n');
fprintf(f,'fxd x_reg[nX_CTRL];\n\n');
fprintf(f,'fxd u_reg[nU];\n\n');
fprintf(f,'static fxd u_old[nU];\n\n');
fprintf(f,'static bool firstCall = true;\n\n');
if nxref ~= 0
    fprintf(f,'fxd x_aug[nX_CTRL];\n\n');
    fprintf(f,'fxd ref_reg[nX];\n\n');
    fprintf(f,'fxd ref_aug[nX_CTRL];\n\n');
    fprintf(f,'fxd delta_u[nU];\n\n');
    fprintf(f,'static fxd q[nDim_CTRL];\n\n');
end
if np ~= 0
    fprintf(f,'fxd p_reg[nP];\n\n');
end
if nd ~= 0
    fprintf(f,'fxd d_reg[nD];\n\n');
end

fprintf(f,'static fxd v1[nDim_CTRL];\n\n');
fprintf(f,'static fxd v2[nCon + (N+1)*nX_CTRL];\n\n');

fprintf(f,'fxd z[nDim_CTRL];\n\n');

if circuit_parameters.useADC == 1
    fprintf(f,'scaleY(y_in, y_reg);\n\n');
    if nxref ~= 0
        fprintf(f,'scaleRef(ref_in, ref_reg);\n\n');
    end
    if np ~= 0
        fprintf(f,'scaleP(p_in, p_reg);\n\n');
    end
else
    fprintf(f,'for (int i = 0; i < nY; i++)\n{\n');
    fprintf(f,'\t#pragma HLS UNROLL\n');
    fprintf(f,'\ty_reg[i] = y_in[i];\n');
    if nxref ~= 0
        fprintf(f,'\tref_reg[i] = 0;\n}\n\n');
        fprintf(f,'for (int i = 0; i < nRef; i++)\n{\n');
        fprintf(f,'\t#pragma HLS UNROLL\n');
        fprintf(f,'\tref_reg[ref_idx[i]] = ref_in[i];\n}\n\n');
    else
        fprintf(f,'}\n\n');
    end
    if np ~= 0
        fprintf(f,'for (int i = 0; i < nP; i++)\n{\n');
        fprintf(f,'\t#pragma HLS UNROLL\n');
        fprintf(f,'\tp_reg[i] = p_in[i];\n}\n\n');
    end
end

fprintf(f,'if (firstCall)\n{\n');
fprintf(f,'\tfor (int i = 0; i < nX_OBS; i++)\n{\n');
fprintf(f,'\t\t#pragma HLS UNROLL\n');
fprintf(f,'\tcurrentState[i] = initial_state[i];\n}\n');
fprintf(f,'\tfor (int i = 0; i < nU; i++)\n{\n');
fprintf(f,'\t\t#pragma HLS UNROLL\n');
fprintf(f,'\tu_old[i] = default_u[i];\n}\n');
fprintf(f,'\tfirstCall = false;\n}\n\n');

if isa(obs, 'kalmanFilter')
    if np ~= 0
        fprintf(f,'corrector(y_reg, p_reg, u_old, currentState);\n\n');
    else
        fprintf(f,'corrector(y_reg, u_old, currentState);\n\n');
    end
end

fprintf(f,'for (int i = 0; i < nX; i++)\n{\n');
fprintf(f,'\t#pragma HLS UNROLL\n');
fprintf(f,'\tx_reg[i] = currentState[i];\n}\n\n');

if nd ~= 0
    fprintf(f,'for (int i = 0; i < nD; i++)\n{\n');
    fprintf(f,'\t#pragma HLS UNROLL\n');
    fprintf(f,'\td_reg[i] = currentState[nX+i];\n}\n\n');
end

if circuit_parameters.useDAC == 1
    fprintf(f,'scaleXout(x_reg, x_est);\n\n');
    if nd ~= 0
        fprintf(f,'scaleDout(d_reg, d_est);\n\n');
    end
else
    fprintf(f,'for (int i = 0; i < nX; i++)\n{\n');
    fprintf(f,'\t#pragma HLS UNROLL\n');
    fprintf(f,'\tx_est[i] = x_reg[i];\n}\n\n');
    if nd ~= 0
        fprintf(f,'for (int i = 0; i < nD; i++)\n{\n');
        fprintf(f,'\t#pragma HLS UNROLL\n');
        fprintf(f,'\td_est[i] = d_reg[i];\n}\n\n');
    end
end

fprintf(f,'if (ctrl_start)\n{\n');

if nxref ~= 0
    fprintf(f,'\taugmentState(x_reg, ref_reg, x_aug, ref_aug, u_old);\n\n');
    if np ~= 0 && nd ~= 0
        fprintf(f,'admmInit(x_aug, p_reg, d_reg, ref_aug, v1, v2);\n\n');
    elseif np ~= 0
        fprintf(f,'admmInit(x_aug, p_reg, ref_aug, v1, v2);\n\n');
    elseif nd ~= 0
        fprintf(f,'admmInit(x_aug, d_reg, ref_aug, v1, v2);\n\n');
    else
        fprintf(f,'admmInit(x_aug, ref_aug, v1, v2);\n\n');
    end
    fprintf(f,'admm(v1, v2, z);\n\n');

    fprintf(f,'\textractU(z, u_reg, u_old);\n\n');
else
    if np ~= 0 && nd ~= 0
        fprintf(f,'admmInit(x_reg, p_reg, d_reg, v1, v2);\n\n');
    elseif np ~= 0
        fprintf(f,'admmInit(x_reg, p_reg, v1, v2);\n\n');
    elseif nd ~= 0
        fprintf(f,'admmInit(x_reg, d_reg, v1, v2);\n\n');
    else
        fprintf(f,'admmInit(x_reg, v1, v2);\n\n');
    end
    fprintf(f,'admm(v1, v2, z);\n\n');
    
    fprintf(f,'\tfor (int i = 0; i < nU; i++)\n{\n');
    fprintf(f,'\t\t#pragma HLS UNROLL\n');
    fprintf(f,'\t\tu_reg[i] = z[i];\n');
    fprintf(f,'\t\tu_old[i] = u_reg[i];\n}\n\n');
end

if circuit_parameters.useDAC == 1
    fprintf(f,'\tscaleU(u_reg, u_opt);\n\n');
else
    fprintf(f,'\tfor (int i = 0; i < nU; i++)\n{\n');
    fprintf(f,'\t\t#pragma HLS UNROLL\n');
    fprintf(f,'\t\tu_opt[i] = u_reg[i];\n}\n\n');
end

fprintf(f,'}\n');

if np ~= 0
    fprintf(f,'predictor(y_reg, p_reg, u_old, currentState);\n\n');
else
    fprintf(f,'predictor(y_reg, u_old, currentState);\n\n');
end

fprintf(f,'}\n');

% Close the main file
fclose(f);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%% COPY C++ FILES FOR CONTROLLER AND ADMM %%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Copy the appropriate C++ files
if circuit_parameters.useADC == 1
    copyfile([getcpppath,'/embeddedSystem/scaleY.cpp'],[folder,'/cpp/scaleY.cpp']);
    if np ~= 0
        copyfile([getcpppath,'/implicitMPCctrl/scaleP.cpp'],[folder,'/cpp/scaleP.cpp']);
    end
    if nxref ~= 0
        copyfile([getcpppath,'/implicitMPCctrl/scaleRef.cpp'],[folder,'/cpp/scaleRef.cpp']);
    end
end

if circuit_parameters.useDAC == 1
    copyfile([getcpppath,'/implicitMPCctrl/scaleU.cpp'],[folder,'/cpp/scaleU.cpp']);
    
    S = fileread([folder,'/cpp/scaleU.cpp']);
    S = strrep(S,'controller.h','embeddedSystem.h');
    f = fopen([folder,'/cpp/scaleU.cpp'],'w');
    fwrite(f, S);
    fclose(f);
    
    copyfile([getcpppath,'/embeddedSystem/scaleXout.cpp'],[folder,'/cpp/scaleXout.cpp']);
    if nd ~= 0
        copyfile([getcpppath,'/embeddedSystem/scaleDout.cpp'],[folder,'/cpp/scaleDout.cpp']);
    end
end

copyfile([getcpppath,'/embeddedSystem/predictor.cpp'],[folder,'/cpp/predictor.cpp']);
S = fileread([folder,'/cpp/predictor.cpp']);
if np ~= 0
    S = strrep(S,'/*p','');
    S = strrep(S,'p*/','');
else
    S = strrep(S,'void predictor(fxd y[nY], fxd p[nP], fxd u_old[nU], fxd currentState[nX_OBS])','void predictor(fxd y[nY], fxd u_old[nU], fxd currentState[nX_OBS])');
end
f = fopen([folder,'/cpp/predictor.cpp'],'w');
fwrite(f, S);
fclose(f);

if isa(obs, 'kalmanFilter')
    copyfile([getcpppath,'/embeddedSystem/corrector.cpp'],[folder,'/cpp/corrector.cpp']);    
    S = fileread([folder,'/cpp/corrector.cpp']);
    if np ~= 0
        S = strrep(S,'/*p','');
        S = strrep(S,'p*/','');
    else
        S = strrep(S,'void corrector(fxd y[nY], fxd p[nP], fxd u_old[nU], fxd currentState[nX_OBS])','void corrector(fxd y[nY], fxd u_old[nU], fxd currentState[nX_OBS])');
    end
    f = fopen([folder,'/cpp/corrector.cpp'],'w');
    fwrite(f, S);
    fclose(f);
end

copyfile([getcpppath,'/implicitMPCctrl/admmInit.cpp'],[folder,'/cpp/admmInit.cpp']);
copyfile([getcpppath,'/implicitMPCctrl/admm.cpp'],[folder,'/cpp/admm.cpp']);

if nxref ~= 0
    copyfile([getcpppath,'/implicitMPCctrl/augmentState.cpp'],[folder,'/cpp/augmentState.cpp']);
    copyfile([getcpppath,'/implicitMPCctrl/extractU.cpp'],[folder,'/cpp/extractU.cpp']);
end

S = fileread([folder,'/cpp/admmInit.cpp']);
S = strrep(S,'controller.h','embeddedSystem.h');
f = fopen([folder,'/cpp/admmInit.cpp'],'w');
fwrite(f, S);
fclose(f);

if np ~= 0
    S = fileread([folder,'/cpp/admmInit.cpp']);
    S = strrep(S,'/*p','');
    S = strrep(S,'p*/','');
    f = fopen([folder,'/cpp/admmInit.cpp'],'w');
    fwrite(f, S);
    fclose(f);

    S = fileread([folder,'/cpp/scaleP.cpp']);
    S = strrep(S,'controller.h','embeddedSystem.h');
    f = fopen([folder,'/cpp/scaleP.cpp'],'w');
    fwrite(f, S);
    fclose(f);
end

if nd ~= 0
    S = fileread([folder,'/cpp/admmInit.cpp']);
    S = strrep(S,'/*d','');
    S = strrep(S,'d*/','');
    f = fopen([folder,'/cpp/admmInit.cpp'],'w');
    fwrite(f, S);
    fclose(f);
end

if nxref ~= 0
    S = fileread([folder,'/cpp/scaleRef.cpp']);
    S = strrep(S,'controller.h','embeddedSystem.h');
    f = fopen([folder,'/cpp/scaleRef.cpp'],'w');
    fwrite(f, S);
    fclose(f);
    
    S = fileread([folder,'/cpp/admmInit.cpp']);
    S = strrep(S,'/*ref','');
    S = strrep(S,'ref*/','');
    f = fopen([folder,'/cpp/admmInit.cpp'],'w');
    fwrite(f, S);
    fclose(f);

    S = fileread([folder,'/cpp/augmentState.cpp']);
    S = strrep(S,'controller.h','embeddedSystem.h');
    f = fopen([folder,'/cpp/augmentState.cpp'],'w');
    fwrite(f, S);
    fclose(f);

    S = fileread([folder,'/cpp/extractU.cpp']);
    S = strrep(S,'controller.h','embeddedSystem.h');
    f = fopen([folder,'/cpp/extractU.cpp'],'w');
    fwrite(f, S);
    fclose(f);
end

if nxref ~= 0
    if np ~= 0 && nd ~= 0
        S = fileread([folder,'/cpp/admmInit.cpp']);
        S = strrep(S,'void admmInit(fxd x[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])','void admmInit(fxd x[nX_CTRL], fxd p[nP], fxd d[nD], fxd ref[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])');
        f = fopen([folder,'/cpp/admmInit.cpp'],'w');
        fwrite(f, S);
        fclose(f);
    elseif np ~= 0
        S = fileread([folder,'/cpp/admmInit.cpp']);
        S = strrep(S,'void admmInit(fxd x[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])','void admmInit(fxd x[nX_CTRL], fxd p[nP], fxd ref[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])');
        f = fopen([folder,'/cpp/admmInit.cpp'],'w');
        fwrite(f, S);
        fclose(f);
    elseif nd ~= 0
        S = fileread([folder,'/cpp/admmInit.cpp']);
        S = strrep(S,'void admmInit(fxd x[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])','void admmInit(fxd x[nX_CTRL], fxd d[nD], fxd ref[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])');
        f = fopen([folder,'/cpp/admmInit.cpp'],'w');
        fwrite(f, S);
        fclose(f);
    else
        S = fileread([folder,'/cpp/admmInit.cpp']);
        S = strrep(S,'void admmInit(fxd x[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])','void admmInit(fxd x[nX_CTRL], fxd ref[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])');
        f = fopen([folder,'/cpp/admmInit.cpp'],'w');
        fwrite(f, S);
        fclose(f);
    end
else
    if np ~= 0 && nd ~= 0
        S = fileread([folder,'/cpp/admmInit.cpp']);
        S = strrep(S,'void admmInit(fxd x[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])','void admmInit(fxd x[nX_CTRL], fxd p[nP], fxd d[nD], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])');
        f = fopen([folder,'/cpp/admmInit.cpp'],'w');
        fwrite(f, S);
        fclose(f);
    elseif np ~= 0
        S = fileread([folder,'/cpp/admmInit.cpp']);
        S = strrep(S,'void admmInit(fxd x[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])','void admmInit(fxd x[nX_CTRL], fxd p[nP], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])');
        f = fopen([folder,'/cpp/admmInit.cpp'],'w');
        fwrite(f, S);
        fclose(f);
    elseif nd ~= 0
        S = fileread([folder,'/cpp/admmInit.cpp']);
        S = strrep(S,'void admmInit(fxd x[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])','void admmInit(fxd x[nX_CTRL], fxd d[nD], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])');
        f = fopen([folder,'/cpp/admmInit.cpp'],'w');
        fwrite(f, S);
        fclose(f);
    else
        S = fileread([folder,'/cpp/admmInit.cpp']);
        S = strrep(S,'void admmInit(fxd x[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])','void admmInit(fxd x[nX_CTRL], fxd v1[nDim_CTRL], fxd v2[nCon + (N+1)*nX_CTRL])');
        f = fopen([folder,'/cpp/admmInit.cpp'],'w');
        fwrite(f, S);
        fclose(f);
    end
end

S = fileread([folder,'/cpp/admm.cpp']);
S = strrep(S,'controller.h','embeddedSystem.h');
if nxref == 0
    S = strrep(S,'DIM_TO_REPLACE',num2str(nDim + 2*nCon + (N+1)*nx));
else
    S = strrep(S,'DIM_TO_REPLACE',num2str(nDim + 2*nCon + (N+1)*(nx+nu)));
end
f = fopen([folder,'/cpp/admm.cpp'],'w');
fwrite(f, S);
fclose(f);
    
if circuit_parameters.architecture == "small"   
 
    S = fileread([folder,'/cpp/admm.cpp']);
    S = strrep(S,'#pragma HLS allocation operation instances=mul','//');
    S = strrep(S,'#pragma HLS UNROLL //small','#pragma HLS PIPELINE');
    f = fopen([folder,'/cpp/admm.cpp'],'w');
    fwrite(f, S);
    fclose(f);
    
elseif circuit_parameters.architecture == "intermediate"
    % TO DO: PARTIALLY UNROLL LOOPS WITH APPROPRIATE ARRAY_PARTITION: 
    % e.g. (#pragam HLS UNROLL factor=2, #pragma HLS ARRAY_PARTITION factor=2 cyclic)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%% GENERATE .TCL FILE AND SYNTHESIZE RTL CODE %%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cd(folder)

% Generate a .tcl file to be executed by Vitis HLS to syntesize C++ code
f = fopen([folder,'/TCLscript.tcl'],'w');

folder = strrep(folder, '\', '/');

fprintf(f,'open_project HLSproject\n');
fprintf(f,'set_top embeddedSystem\n');
fprintf(f,'add_files %s\n', [folder, 'cpp/embeddedSystem.h']);
fprintf(f,'add_files %s\n', [folder, 'cpp/embeddedSystem.cpp']);

if circuit_parameters.useADC == 1
    fprintf(f,'add_files %s\n', [folder, 'cpp/scaleY.cpp']);
    if np ~= 0
        fprintf(f,'add_files %s\n', [folder, 'cpp/scaleP.cpp']);
    end
    if nxref ~= 0
        fprintf(f,'add_files %s\n', [folder, 'cpp/scaleRef.cpp']);
    end
end

if circuit_parameters.useDAC == 1
    fprintf(f,'add_files %s\n', [folder, 'cpp/scaleU.cpp']);
    fprintf(f,'add_files %s\n', [folder, 'cpp/scaleXout.cpp']);
    if nd ~= 0
        fprintf(f,'add_files %s\n', [folder, 'cpp/scaleDout.cpp']);
    end
end

if nxref ~= 0
    fprintf(f,'add_files %s\n', [folder, 'cpp/augmentState.cpp']);
    fprintf(f,'add_files %s\n', [folder, 'cpp/extractU.cpp']);
end

if isa(obs, 'kalmanFilter')
    fprintf(f,'add_files %s\n', [folder, 'cpp/corrector.cpp']);
end
fprintf(f,'add_files %s\n', [folder, 'cpp/predictor.cpp']);

fprintf(f,'add_files %s\n', [folder, 'cpp/admmInit.cpp']);
fprintf(f,'add_files %s\n', [folder, 'cpp/admm.cpp']);
fprintf(f,'open_solution "solution1" -flow_target vivado\n');
fprintf(f,'set_part {%s}\n', fpgaBoard);
fprintf(f,'create_clock -period %d -name default\n', 1e9/frequency);
fprintf(f,'config_rtl -reset control -reset_level low\n');
fprintf(f,'csynth_design\n');
% fprintf(f,'export_design -rtl vhdl -format ip_catalog\n');
% fprintf(f,'export_design -rtl vhdl -format sysgen -flow syn\n');
fprintf(f,'close_project\n');
fprintf(f,'quit\n');

fclose(f);

% Run Vitis HLS and hide its output messages with 'evalc'
evalc('status = system(''vitis_hls -f TCLscript.tcl'')');

cd ..

if status ~= 0
    warning('ERROR: Vitis HLS not found or not working properly!')
else
    % Copy VHDL files generated with HLS synthesis
    copyfile((strcat(folder, '/HLSproject/solution1/syn/vhdl/*.vhd')),(strcat(folder, '/vhdl')));
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% GENERATE .VHD CODE FOR EMBEDDED SYSTEM INTERFACE %%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% If needed generate interface
if generateInterface
    % Generate VHDL file for the interface
    f = fopen([folder,'/vhdl/embeddedSystemInterface.vhd'],'w');

    fprintf(f,'library IEEE;\n');
    fprintf(f,'use IEEE.STD_LOGIC_1164.ALL;\n\n');

    fprintf(f,'entity embeddedSystemInterface is\n');
    fprintf(f,'Port ( clk : in STD_LOGIC;\n');
    fprintf(f,'\tce : in STD_LOGIC;\n');
    fprintf(f,'\treset : in STD_LOGIC;\n');
    fprintf(f,'\tobs_start : in STD_LOGIC;\n');
    fprintf(f,'\tctrl_start : in STD_LOGIC;\n');

    for i=1:np
        fprintf(f,'\tp%d : in STD_LOGIC_VECTOR (%d downto 0);\n', i, nbit-1);
    end
    if ctrl.isTracking
        for i=1:nxref
            fprintf(f,'\txref%d : in STD_LOGIC_VECTOR (%d downto 0);\n', i, nbit-1);
        end
    end
    for i=1:ny
        fprintf(f,'\ty%d : in STD_LOGIC_VECTOR (%d downto 0);\n', i, nbit-1);
    end
    for i=1:nu
        fprintf(f,'\tu%d : out STD_LOGIC_VECTOR (%d downto 0) := "%s";\n', i, nbitout-1, do_bin{i});
    end

    fprintf(f,'\tsample : out STD_LOGIC := ''0'';\n');
    fprintf(f,'\toutput_ready : out STD_LOGIC := ''0''\n');
    fprintf(f,');\n');

    fprintf(f,'end embeddedSystemInterface;\n\n');

    fprintf(f,'architecture Behavioral of embeddedSystemInterface is\n\n');

    % Add observer component
    fprintf(f,'COMPONENT embeddedSystem\n');
    fprintf(f,'PORT (\n');
    fprintf(f,'\tap_clk : IN STD_LOGIC;\n');
    fprintf(f,'\tap_rst_n : IN STD_LOGIC;\n');
    fprintf(f,'\tap_start : IN STD_LOGIC;\n');
    fprintf(f,'\tap_done : OUT STD_LOGIC;\n');
    fprintf(f,'\tap_idle : OUT STD_LOGIC;\n');
    fprintf(f,'\tap_ready : OUT STD_LOGIC;\n');
    if np==1
        fprintf(f,'\tp_in : in STD_LOGIC_VECTOR (%d downto 0);\n', circuit_parameters.inputResolution-1);
    else
        for i=1:np
            fprintf(f,'\tp_in_%d : in STD_LOGIC_VECTOR (%d downto 0);\n', i-1, circuit_parameters.inputResolution-1);
        end
    end
    if ny==1
        fprintf(f,'\ty_in : in STD_LOGIC_VECTOR (%d downto 0);\n', circuit_parameters.inputResolution-1);
    else
        for i=1:ny
            fprintf(f,'\ty_in_%d : in STD_LOGIC_VECTOR (%d downto 0);\n', i-1, circuit_parameters.inputResolution-1);
        end
    end
    if ctrl.isTracking
        if nxref==1
            fprintf(f,'\tref_in : in STD_LOGIC_VECTOR (%d downto 0);\n', circuit_parameters.inputResolution-1);
        else
            for i=1:nxref
                fprintf(f,'\tref_in_%d : in STD_LOGIC_VECTOR (%d downto 0);\n', i-1, circuit_parameters.inputResolution-1);
            end
        end
    end
    fprintf(f,'\tctrl_start : IN STD_LOGIC;\n');
    if nx==1
        fprintf(f,'\tx_est : out STD_LOGIC_VECTOR (%d downto 0) := "%s";\n', circuit_parameters.outputResolution-1, initialState_bin{1});
        fprintf(f,'\tx_est_ap_vld : OUT STD_LOGIC;\n');
    else
        for i=1:nx
            fprintf(f,'\tx_est_%d : out STD_LOGIC_VECTOR (%d downto 0) := "%s";\n', i-1, circuit_parameters.outputResolution-1, initialState_bin{i});
            fprintf(f,'\tx_est_%d_ap_vld : OUT STD_LOGIC', i-1);
            fprintf(f,';\n');
        end
    end
    if nd==1
        fprintf(f,'\td_est : out STD_LOGIC_VECTOR (%d downto 0) := "%s";\n', circuit_parameters.outputResolution-1, initialState_bin{1});
        fprintf(f,'\td_est_ap_vld : OUT STD_LOGIC;\n');
    else
        for i=1:nd
            fprintf(f,'\td_est_%d : out STD_LOGIC_VECTOR (%d downto 0) := "%s";\n', i-1, circuit_parameters.outputResolution-1, initialState_bin{i});
            fprintf(f,'\td_est_%d_ap_vld : OUT STD_LOGIC', i-1);
            fprintf(f,';\n');
        end
    end
    if nu==1
        fprintf(f,'\tu_opt : out STD_LOGIC_VECTOR (%d downto 0) := "%s";\n', circuit_parameters.outputResolution-1, do_bin{1});
        fprintf(f,'\tu_opt_ap_vld : OUT STD_LOGIC');
    else
        for i=1:nu
            fprintf(f,'\tu_opt_%d : out STD_LOGIC_VECTOR (%d downto 0) := "%s";\n', i-1, circuit_parameters.outputResolution-1, do_bin{i});
            fprintf(f,'\tu_opt_%d_ap_vld : OUT STD_LOGIC', i-1);
            if i~=nu
                fprintf(f,';\n');
            end
        end
    end
    fprintf(f,');\n');
    fprintf(f,'END COMPONENT;\n\n');

    fprintf(f,'signal kalman_start : STD_LOGIC := ''0'';\n');
    fprintf(f,'signal admm_start : STD_LOGIC := ''0'';\n');
    fprintf(f,'signal done : STD_LOGIC := ''0'';\n');
    fprintf(f,'signal idle : STD_LOGIC;\n');
    fprintf(f,'signal ready : STD_LOGIC;\n');

    if nx+nd==1
        fprintf(f,'signal pred_state_int : STD_LOGIC_VECTOR (%d downto 0) := "%s";\n', circuit_parameters.outputResolution-1, initialState_bin{1});
        fprintf(f,'signal pred_state_vld : STD_LOGIC;\n');
    else
        for i=1:nx
            fprintf(f,'signal pred_state_int_%d : STD_LOGIC_VECTOR (%d downto 0) := "%s";\n', i, circuit_parameters.outputResolution-1, initialState_bin{i});
            fprintf(f,'signal pred_state_%d_vld : STD_LOGIC;\n', i);
        end
        for i=nx+1:nx+nd
            fprintf(f,'signal pred_state_int_%d : STD_LOGIC_VECTOR (%d downto 0) := (others => ''0'');\n', i, circuit_parameters.outputResolution-1);
            fprintf(f,'signal pred_state_%d_vld : STD_LOGIC;\n', i);
        end
    end

    if nu==1
        fprintf(f,'signal u_opt_int : STD_LOGIC_VECTOR (%d downto 0) := "%s";\n', nbitout-1, do_bin{1});
        fprintf(f,'signal u_opt_vld : STD_LOGIC;\n');
    else
        for i=1:nu
            fprintf(f,'signal u_opt_int_%d : STD_LOGIC_VECTOR (%d downto 0) := "%s";\n', i, nbitout-1, do_bin{i});
            fprintf(f,'signal u_opt_%d_vld : STD_LOGIC;\n', i);
        end
    end

    fprintf(f,'\nbegin\n\n');

    if nu==1
        fprintf(f,'u1 <= "%s" when reset = ''0'' else \n\tu_opt_int when u_opt_vld = ''1'' and rising_edge(clk);\n', do_bin{1});
    else
        for i=1:nu
            fprintf(f,'u%d <= "%s" when reset = ''0'' else \n\tu_opt_int_%d when u_opt_%d_vld = ''1'' and rising_edge(clk);\n', i, i, do_bin{i});
        end
    end
    fprintf(f,'\n');

    if nu==1
        fprintf(f,'output_ready <= ''0'' when reset = ''0'' else \n\tu_opt_vld when rising_edge(clk);\n');
    else
        fprintf(f,'output_ready <= ''0'' when reset = ''0'' else \n\tu_opt_1_vld when rising_edge(clk);\n');
        for i=2:nu
            fprintf(f,'and u_opt_%d_vld\n', i);
        end
        fprintf(f,' when rising_edge(clk);\n');
    end
    fprintf(f,'\n');    

    fprintf(f,'embSys : embeddedSystem\n');
    fprintf(f,'PORT MAP (\n');
    fprintf(f,'\tap_clk => clk,\n');
    fprintf(f,'\tap_rst_n => reset,\n');
    fprintf(f,'\tap_start => kalman_start,\n');
    fprintf(f,'\tap_done => done,\n');
    fprintf(f,'\tap_idle => idle,\n');
    fprintf(f,'\tap_ready => ready,\n');
    if np==1
        fprintf(f,'\tp_in => p1,\n');
    else
        for i=1:np
            fprintf(f,'\tp_in_%d => p%d,\n', i-1, i);
        end
    end
    if ny==1
        fprintf(f,'\ty_in => y1,\n');
    else
        for i=1:ny
            fprintf(f,'\ty_in_%d => y%d,\n', i-1, i);
        end
    end
    if ctrl.isTracking
        if nxref==1
            fprintf(f,'\tref_in => xref1,\n');
        else
            for i=1:nxref
                fprintf(f,'\tref_in_%d => xref%d,\n', i-1, i);
            end
        end
    end
    fprintf(f,'\tctrl_start => admm_start,\n');
    if nx==1
        fprintf(f,'\tx_est => pred_state_int,\n');
        fprintf(f,'\tx_est_ap_vld => pred_state_vld');
    else
        for i=1:nx
            fprintf(f,'\tx_est_%d => pred_state_int_%d,\n', i-1, i);
            fprintf(f,'\tx_est_%d_ap_vld => pred_state_%d_vld', i-1, i);
            fprintf(f,',\n');
        end
    end
    if nd==1
        fprintf(f,'\td_est => pred_state_int,\n');
        fprintf(f,'\td_est_ap_vld => pred_state_vld');
    else
        for i=1:nd
            fprintf(f,'\td_est_%d => pred_state_int_%d,\n', i-1, i);
            fprintf(f,'\td_est_%d_ap_vld => pred_state_%d_vld', i-1, i);
            fprintf(f,',\n');
        end
    end
    if nu==1
        fprintf(f,'\tu_opt => u_opt_int,\n');
        fprintf(f,'\tu_opt_ap_vld => u_opt_vld');
    else
        for i=1:nu
            fprintf(f,'\tu_opt_%d => u_opt_int_%d,\n', i-1, i);
            fprintf(f,'\tu_opt_ap_vld => u_opt_vld');
            if i~=nu
                 fprintf(f,',\n');
            end
        end
    end
    fprintf(f,');\n\n');
    
    
    fprintf(f,'process(clk, reset)\n');
    fprintf(f,'begin\n');
    fprintf(f,'\tif reset = ''0'' then\n');
    fprintf(f,'\t\tkalman_start <= ''0'';\n');
    fprintf(f,'\t\tadmm_start <= ''0'';\n');
    fprintf(f,'\t\tsample <= ''0'';\n');
    fprintf(f,'\telsif rising_edge(clk) then\n');
    fprintf(f,'\t\tif obs_start = ''1'' and ctrl_start = ''1'' then\n');
    fprintf(f,'\t\t\tkalman_start <= ''1'';\n');
    fprintf(f,'\t\t\tadmm_start <= ''1'';\n');
    fprintf(f,'\t\t\tsample <= ''1'';\n');
    fprintf(f,'\t\telsif obs_start = ''1'' and ctrl_start = ''0'' then\n');
    fprintf(f,'\t\t\tkalman_start <= ''1'';\n');
    fprintf(f,'\t\t\tadmm_start <= ''0'';\n');
    fprintf(f,'\t\t\tsample <= ''0'';\n');
    fprintf(f,'\t\telsif ready = ''1'' then\n');
    fprintf(f,'\t\t\tkalman_start <= ''0'';\n');
    fprintf(f,'\t\t\tadmm_start <= ''0'';\n');
    fprintf(f,'\t\t\tsample <= ''0'';\n');
    fprintf(f,'\t\telse\n');
    fprintf(f,'\t\t\tkalman_start <= kalman_start;\n');
    fprintf(f,'\t\t\tadmm_start <= admm_start;\n');
    fprintf(f,'\t\t\tsample <= ''0'';\n');
    fprintf(f,'\t\tend if;\n');
    fprintf(f,'\tend if;\n');
    fprintf(f,'end process;\n');

    fprintf(f,'end Behavioral;\n');

    fclose(f);

end

disp('Done.')
disp(' ')

if status == 0
    % Generate a report for HLS synthesis
    copyfile((strcat(folder, '/HLSproject/solution1/syn/report/csynth.rpt')),(strcat(folder, 'HLS_synthesis_report.rpt')));
end

out.range = circuit_parameters.range;
out.circuit_parameters = circuit_parameters;

%% Circuit report

filename = strcat(folder,'/VHDL_report.log');

fout = fopen(filename, 'w');

fprintf(fout,'-------------------------------------------------------------\n');
fprintf(fout,'|                Circuit information report                  |\n');
fprintf(fout,'-------------------------------------------------------------\n\n');
fprintf(fout,'INPUTS\n');
fprintf(fout,'\t - Resolution: %d bits\n',circuit_parameters.inputResolution);
fprintf(fout,'\t - Representation: %s\n',circuit_parameters.inputRepresentation);
fprintf(fout,'\t - Range (model --> circuit):\n');

if circuit_parameters.useADC == 1
    for i = 1:np
        if strcmp(circuit_parameters.inputRepresentation,'signed')
            cirmin = decimal2signed(circuit_parameters.inputRange.min(i),nbit,0);
            cirmax = decimal2signed(circuit_parameters.inputRange.max(i),nbit,0);
        else
            cirmin = decimal2unsigned(circuit_parameters.inputRange.min(i),nbit,0);
            cirmax = decimal2unsigned(circuit_parameters.inputRange.max(i),nbit,0);
        end
        fprintf(fout,'\t\t%s: [%f %f] --> p%d: [%s %s]\n',object.pnames{i},range.pmin(i),range.pmax(i),i,cirmin.bin,cirmax.bin);
    end

    for i = 1:ny
        if strcmp(circuit_parameters.inputRepresentation,'signed')
            cirmin = decimal2signed(circuit_parameters.inputRange.min(np+i),nbit,0);
            cirmax = decimal2signed(circuit_parameters.inputRange.max(np+i),nbit,0);
        else
            cirmin = decimal2unsigned(circuit_parameters.inputRange.min(np+i),nbit,0);
            cirmax = decimal2unsigned(circuit_parameters.inputRange.max(np+i),nbit,0);
        end
        fprintf(fout,'\t\t%s: [%f %f] --> y%d: [%s %s]\n',object.ynames{i},range.ymin(i),range.ymax(i),i,cirmin.bin,cirmax.bin);
    end

    ii = ctrl.getTrackingVariable;
    for i = 1:nxref
        if strcmp(circuit_parameters.inputRepresentation,'signed')
            cirmin = decimal2signed(circuit_parameters.inputRange.min(np+ny+i),nbit,0);
            cirmax = decimal2signed(circuit_parameters.inputRange.max(np+ny+i),nbit,0);
        else
            cirmin = decimal2unsigned(circuit_parameters.inputRange.min(np+ny+i),nbit,0);
            cirmax = decimal2unsigned(circuit_parameters.inputRange.max(np+ny+i),nbit,0);
        end
        fprintf(fout,'\t\t%s reference: [%f %f] --> x%d_ref: [%s %s]\n',object.xnames{ii(i)},range.xrefmin(i),range.xrefmax(i),ii(i),cirmin.bin,cirmax.bin);
    end
else
    for i = 1:np
        if strcmp(circuit_parameters.inputRepresentation,'signed')
            cirmin = decimal2signed(range.pmin(i),nbit,nbit-nbitInt-1);
            cirmax = decimal2signed(range.pmax(i),nbit,nbit-nbitInt-1);
        else
            cirmin = decimal2signed(range.pmin(i),nbit,nbit-nbitInt);
            cirmax = decimal2signed(range.pmax(i),nbit,nbit-nbitInt);
        end
        fprintf(fout,'\t\t%s: [%f %f] --> p%d: [%s %s]\n',object.pnames{i},range.pmin(i),range.pmax(i),i,cirmin.bin,cirmax.bin);
    end

    for i = 1:ny
            if strcmp(circuit_parameters.inputRepresentation,'signed')
                cirmin = decimal2signed(range.ymin(i),nbit,nbit-nbitInt-1);
                cirmax = decimal2signed(range.ymax(i),nbit,nbit-nbitInt-1);
            else
                cirmin = decimal2signed(range.ymin(i),nbit,nbit-nbitInt);
                cirmax = decimal2signed(range.ymax(i),nbit,nbit-nbitInt);
            end
        fprintf(fout,'\t\t%s: [%f %f] --> y%d: [%s %s]\n',object.ynames{i},range.ymin(i),range.ymax(i),i,cirmin.bin,cirmax.bin);
    end

    ii = ctrl.getTrackingVariable;
    for i = 1:nxref
        if strcmp(circuit_parameters.inputRepresentation,'signed')
            cirmin = decimal2signed(range.xrefmin(i),nbit,nbit-nbitInt-1);
            cirmax = decimal2signed(range.xrefmax(i),nbit,nbit-nbitInt-1);
        else
            cirmin = decimal2signed(range.xrefmin(i),nbit,nbit-nbitInt);
            cirmax = decimal2signed(range.xrefmax(i),nbit,nbit-nbitInt);
        end
        fprintf(fout,'\t\t%s reference: [%f %f] --> x%d_ref: [%s %s]\n',object.xnames{ii(i)},range.xrefmin(i),range.xrefmax(i),ii(i),cirmin.bin,cirmax.bin);
    end
end


fprintf(fout,'\nOUTPUTS\n');
fprintf(fout,'\t - Resolution: %d bits\n',circuit_parameters.outputResolution);
fprintf(fout,'\t - Representation: %s\n',circuit_parameters.outputRepresentation);
fprintf(fout,'\t - Range (model --> circuit):\n');
if circuit_parameters.useDAC == 1
    for i = 1:nu
        if strcmp(circuit_parameters.outputRepresentation,'signed')
            ucirmin = decimal2signed(circuit_parameters.outputRange.min(i),nbitout,0);
            ucirmax = decimal2signed(circuit_parameters.outputRange.max(i),nbitout,0);
        else
            ucirmin = decimal2unsigned(circuit_parameters.outputRange.min(i),nbitout,0);
            ucirmax = decimal2unsigned(circuit_parameters.outputRange.max(i),nbitout,0);
        end
        fprintf(fout,'\t\t%s: [%f %f] --> u%d: [%s %s]\n',object.unames{i},range.umin(i),range.umax(i),i,ucirmin.bin,ucirmax.bin);
    end
else
    for i = 1:nu
        if strcmp(circuit_parameters.outputRepresentation,'signed')
            ucirmin = decimal2signed(range.umin(i),nbitout,nbitout-nbitIntOut-1);
            ucirmax = decimal2signed(range.umax(i),nbitout,nbitout-nbitIntOut-1);
        else
            ucirmin = decimal2signed(range.umin(i),nbitout,nbitout-nbitIntOut);
            ucirmax = decimal2signed(range.umax(i),nbitout,nbitout-nbitIntOut);
        end
        fprintf(fout,'\t\t%s: [%f %f] --> u%d: [%s %s]\n',object.unames{i},range.umin(i),range.umax(i),i,ucirmin.bin,ucirmax.bin);
    end
end
fprintf(fout,'\nCOEFFICIENTS\n');
fprintf(fout,'\t - Resolution: %d bits\n',circuit_parameters.coeffResolution);
fprintf(fout,'\t - Integer part: %d bits\n',circuit_parameters.coeffIntResolution);
fprintf(fout,'\n');
fprintf(fout,'FREQUENCY:\r\n');
if frequency < 1000
    fprintf(fout,'\t - Working frequency = %f Hz\n\n',frequency);
elseif frequency < 1000000
    fprintf(fout,'\t - Working frequency = %f kHz\n\n',frequency/1e3);
else
    fprintf(fout,'\t - Working frequency = %f MHz\n\n',frequency/1e6);
end

fprintf(fout,'-------------------------------------------------------------\n');
fprintf(fout,'Check ''HLS_synthesis_report.rpt'' for latency and area occupation.\n');

fclose(fout);
edit([folder ,'/VHDL_report.log'])

end
