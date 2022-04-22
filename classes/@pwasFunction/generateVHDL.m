function varargout = generateVHDL(object, varargin)
% generateVHDL
% Generates the VHDL files describing the digital circuit implementing
% the pwas function
%
% generateVHDL(OBJ)
% Generates the VHDL files for the circuit implementation on FPGA of all
% components of the possibly vector PWAS function with the default options.
% Several VHDL files are generated, the top-level block is pwasFunction.vhd
% A report is also generated showing the main circuit features (latency,
% multipliers, etc.). A fixed point data representation is used.
%
% generateVHDL(OBJ,IDX)
% Generates the VHDL files for the circuit implementation on FPGA of the
% components of the vector PWAS function indicated by IDX, with the default
% options. IDX is a vector containing the indices of the components to
% implement. A report is also generated showing the main circuit features
% (latency, multipliers, etc.).
%
% generateVHDL(OBJ,OPTS)
% Generates the VHDL files for the circuit implementation on FPGA of all
% components of the possibly vector PWAS function with custom options.
% OPTS is a structure with the following fields:
%  -  architecture: can be either 'fast' (default) or 'small'. The first
%                   choice produces a circuit with lower latency and bigger
%                   size, the second one viceversa.
%  -  inputResolution: number of bits used to represent the function
%                      inputs. In general, it corresponds to the resolution
%                      of the analog-to-digital converters (ADC). Default
%                      value: 12.
%  -  inputRepresentation: can be either 'signed' or 'unsigned'. This also
%                          depends on the ADCs. Default value: 'signed'.
%  -  inputRange: structure with fields min and max, indicating the minimum
%                 and maximum value of the circuit inputs. min and max must
%                 be integer values representable with the number of bits
%                 chosen in inputResolution. For example if inputResolution
%                 = 8 and inputRepresentation = 'unsigned', min and max
%                 must be integer numbers comprised betwen 0 and 255. In
%                 this case, if 0 and 255 are chosen as inputRange.min and
%                 inputRange.max, the maximum representation range is
%                 exploited. Default: maximum representable range.
%  -  coeffResolution: number of bits used to represent the coefficients.
%                      This value is in general bounded by the resolution
%                      of the multipliers available on the FPGA. Default
%                      value: inputResolution.
%  -  outputResolution: number of bits used to represent the function
%                       outputs. In general, it corresponds to the resolution
%                       of the digital-to-analog converters (DAC). Default
%                       value: coeffResolution.
%  -  outputRepresentation: can be either 'signed' or 'unsigned'. This also
%                           depends on the DACs. Default value: 'signed'.
%  -  outputRange: structure with fields min and max, indicating the minimum
%                  and maximum value of the circuit outputs. Default: maximum
%                  representable range.
%  -  frequency: clock frequency (in Hz) of the FPGA. This information is 
%                used to calculate the circuit latency.  Default value:
%                50000000 (50 MHz).
%  -  generateInterface: flag indicating if a circuit interface must be
%                        generated. If the pwasFunction is part of a 
%                        controller, the interface must not be generated. 
%                        Default value: true.
%  -  folder: folder where VHDL files are created. Default value: progressive
%             folder.
% A report is also generated showing the main circuit features (latency,
% multipliers, etc.).
%
% PERF = generateVHDL(OBJ,...)
% If an output argument is provided, the report is not automatically opened 
% and a structure PERF containing some information about the circuit 
% implementation is returned. PERF is a structure with the following fields:
%  - latency: circuit latency (in clock cycles)
%  - memory_size: number of elements in the circuit memory
%  - multiplier: number of multipliers
%  - range: structure with the following fields:
%            - xmin, xmax: actual ranges of the function inputs
%            - xmin_cir, xmax_cir: ranges of the function inputs for the
%                                  circuit
%            - umin, umax: actual ranges of the function outputs
%            - umin_cir, umax_cir: ranges of the function outputs for the
%                                  circuit
%  - scale_x: structure with fields A and b, which are the matrices used to 
%             transform the function inputs from their actual range to the
%             circuit range: x_cir = A x + b
%  - scale_u: structure with fields A and b, which are the matrices used to 
%             transform the function outputs from their circuit range to
%             the actual range: u = A u_cir + b

% Contributors:
%
% Alberto Oliveri (alberto.oliveri@unige.it)
% Matteo Lodi (matteo.lodi@edu.unige.it)
%
% Copyright (C) 2016 University of Genoa, Italy.

% Legal note:
% This program is free software; you can redistribute it and/or
% modify it under the terms of the GNU General Public
% License as published by the Free Software Foundation; either
% version 2.1 of the License, or (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% General Public License for more details.
%
% You should have received a copy of the GNU General Public
% License along with this library; if not, write to the
% Free Software Foundation, Inc.,
% 59 Temple Place, Suite 330,
% Boston, MA  02111-1307  USA

% Check input arguments
if nargin == 1
    idx = [];
    opts = [];
elseif nargin == 2
    if isstruct(varargin{1})
        idx = [];
        opts = varargin{1};
    else
        idx = varargin{1};
        opts = [];
    end
elseif nargin == 3
    idx = varargin{1};
    opts = varargin{2};
else
    error('Wrong input arguments');
end

% Get domain and codomain dimensions and number of partitions
ndim = object.getDomainDimensions();
np = object.getNumberOfPartitions();
nfun = object.getCodomainDimensions();

% Check if number of dimensions is lower than 8
if ndim > 8
    error('VHDL code for PWAS functions with more than 8 dimensions cannot be generated');
end

% Set default value for idx
if isempty(idx)
    idx = 1:nfun;
end

if any(idx < 1) || any(idx > nfun)
    error(['IDX must be a vector with elements between 1 and ',num2str(nfun)]);
end

nfun = numel(idx);

% Check and set default options
optout = pwasVHDLset(object,opts,idx);

% Create destination folder
if ~exist(optout.folder,'dir')
    mkdir(optout.folder)
end
disp(['Destination folder: ', optout.folder]);

% Extract number of bits
nbit = optout.inputResolution;
nbitout = optout.outputResolution;
nbit_coeff = optout.coeffResolution;

% Number of bits for integer part of inputs (after scaling)
nint = ceil(log2(np+1));

% Is the partition uniform or non uniform?
uniform = object.isUniform();

% Domain
[Hd, Kd] = object.getDomain();

P = Polyhedron(Hd,Kd);
B = P.outerApprox;

% PWAS function domain
dmin = B.Internal.lb;
dmax = B.Internal.ub;

if ~uniform
    
    % Input range
    xmin = optout.inputRange.min(:);
    xmax = optout.inputRange.max(:);
    
    % Matrices to scale imputs from inputRange to z
    % z = A(x-b)
    A = (xmax-xmin)./(dmax-dmin);
    b = dmin-xmin./A;
    
    % Transform partition in binary form
    P = object.getPartition();
    Pbin = P;
    for i = 1:ndim
        Pcur = A(i)*(P{i}-b(i));
        if strcmpi(optout.inputRepresentation,'signed')
            Pbin{i} = decimal2signed(Pcur,optout.inputResolution,0);
        else
            Pbin{i} = decimal2unsigned(Pcur,optout.inputResolution,0);
        end
    end
    
    % Find coefficients for the PWA scaling
    for i = 1:ndim
        for j = 1:numel(P{i})-1
            % Input range
            xmin = Pbin{i}(j).dec;
            xmax = Pbin{i}(j+1).dec;
            
            % Variable bounds after rescaling
            zmin = 0;
            zmax = 1;
            
            % Matrices to scale imputs from inputRange to z
            % z = A(x-b)
            scaleInput.A{i}(j) = (zmax-zmin)./(xmax-xmin);
            scaleInput.b{i}(j) = xmin-zmin./scaleInput.A{i}(j);
        end
    end
else
    % Input range
    xmin = optout.inputRange.min(:);
    xmax = optout.inputRange.max(:);
    
    % Variable bounds after rescaling ( [ 0 np ] )
    zmin = zeros(ndim,1);
    zmax = np(:);
    
    % Matrices to scale imputs from inputRange to z
    % z = A(x-b)
    scaleInput.b = xmin;
    scaleInput.A = (zmax-zmin)./(xmax-xmin);
    
    Pbin = [];
end

% PWAS function weights
w = object.getWeights;
w = w(:,idx);

% Minimum and maximum weight
wmin = min(w);
wmax = max(w);

% Output range
fmin = optout.outputRange.min;
fmax = optout.outputRange.max;

% Matrices for the rescaling of output function
scaleOutput.A = diag((fmax(:)-fmin(:))./(wmax(:)-wmin(:)));
scaleOutput.b = fmin(:)-scaleOutput.A*wmin(:);
scaleOutput.A = diag(scaleOutput.A);

% Create structure with number of bits
bits.nbit = nbit;
bits.nbit_coeff = nbit_coeff;
bits.nbitout = nbitout;
bits.nint = nint;

% Write VHDL files
object.writePackage(idx,optout,bits,scaleInput,Pbin);
if optout.generateInterface
    object.writeInterface(optout);
end
object.writeMemory(idx,bits,optout,scaleOutput);
object.writeSorter(optout);

% Copy remaining files
folder = optout.folder;
dirvhdl = getvhdlpath();
copyfile([dirvhdl,'/pwasFunction/address_generator.vhd'],...
    [folder,'/address_generator.vhd']);
if ndim > 4
    copyfile([dirvhdl,'/pwasFunction/bitonic8.vhd'],...
        [folder,'/bitonic8.vhd']);
elseif ndim > 2
    copyfile([dirvhdl,'/pwasFunction/bitonic4.vhd'],...
        [folder,'/bitonic4.vhd']);
else
    copyfile([dirvhdl,'/pwasFunction/bitonic2.vhd'],...
        [folder,'/bitonic2.vhd']);
end
copyfile([dirvhdl,'/pwasFunction/comparator.vhd'],...
    [folder,'/comparator.vhd']);
copyfile([dirvhdl,'/pwasFunction/d_selector.vhd'],...
    [folder,'/d_selector.vhd']);
copyfile([dirvhdl,'/pwasFunction/mu_generator.vhd'],...
    [folder,'/mu_generator.vhd']);
if optout.generateInterface
    copyfile([dirvhdl,'/pwasFunction/mulBank.vhd'],...
        [folder,'/mulBank.vhd']);
end
copyfile([dirvhdl,'/pwasFunction/mulBankManager.vhd'],...
    [folder,'/mulBankManager.vhd']);
copyfile([dirvhdl,'/pwasFunction/pwasFunctionCircuit.vhd'],...
    [folder,'/pwasFunctionCircuit.vhd']);
if uniform
    copyfile([dirvhdl,'/pwasFunction/Scale.vhd'],...
        [folder,'/Scale.vhd']);
else
    object.writeScale(optout,bits);
end
if nfun == 1
    copyfile([dirvhdl,'/pwasFunction/Sum1.vhd'],...
        [folder,'/Sum.vhd']);
else
    copyfile([dirvhdl,'/pwasFunction/Sum.vhd'],...
        [folder,'/Sum.vhd']);
end

% Circuit performances
if ndim <= 2
    lat_sort = 1;
elseif ndim <= 4
    lat_sort = 3;
else
    lat_sort = 6;
end

if strcmpi(optout.architecture,'fast')
    lat_mem = 1;
    memory_size = (ndim+1)*numel(w);
else
    lat_mem = ndim+1;
    memory_size = numel(w);
end

latency = lat_sort+lat_mem+numel(idx)+4;
multipliers = ndim+1;

range.xmin = dmin;
range.xmax = dmax;
range.umin = wmin;
range.umax = wmax;

for i = 1:ndim
    if strcmp(optout.inputRepresentation,'signed')
        cirmin = decimal2signed(optout.inputRange.min(i),nbit,0);
        cirmax = decimal2signed(optout.inputRange.max(i),nbit,0);
    else
        cirmin = decimal2unsigned(optout.inputRange.min(i),nbit,0);
        cirmax = decimal2unsigned(optout.inputRange.max(i),nbit,0);
    end
    range.xmin_cir(i) = cirmin.dec;
    range.xmax_cir(i) = cirmax.dec;
end
for i = 1:nfun
    if strcmp(optout.inputRepresentation,'signed')
        cirmin = decimal2signed(optout.outputRange.min(i),nbit,0);
        cirmax = decimal2signed(optout.outputRange.max(i),nbit,0);
    else
        cirmin = decimal2unsigned(optout.outputRange.min(i),nbit,0);
        cirmax = decimal2unsigned(optout.outputRange.max(i),nbit,0);
    end
    range.umin_cir(i) = cirmin.dec;
    range.umax_cir(i) = cirmax.dec;
end

% Transform into column vectors
range.xmin = range.xmin(:);
range.xmax = range.xmax(:);
range.umin = range.umin(:);
range.umax = range.umax(:);
range.xmin_cir = range.xmin_cir(:);
range.xmax_cir = range.xmax_cir(:);
range.umin_cir = range.umin_cir(:);
range.umax_cir = range.umax_cir(:);

% Number of bits for the multiplier
if strcmpi(optout.outputRepresentation,'signed')
    nbit_coeff_eff = nbit_coeff;
else
    nbit_coeff_eff = nbit_coeff+1;
end

nbit_mul = max(nbit+1,nbit_coeff_eff);

if nargout > 1
    error('Wrong number of outputs')
elseif nargout == 1
    
    A = diag((range.xmax_cir-range.xmin_cir)./(range.xmax-range.xmin));
    b = range.xmin_cir-A*range.xmin;
    optO.scale_x.A = A;
    optO.scale_x.b = b;
    A = diag((range.umax-range.umin)./(range.umax_cir-range.umin_cir));
    b = range.umin-A*range.umin_cir;
    optO.scale_u.A = A;
    optO.scale_u.b = b;
    optO.latency = latency;
    optO.memory_size = memory_size;
    optO.multiplier = multipliers;
    optO.nbitmul = nbit_mul;
    optO.range = range;
    varargout{1} = optO;
end

filename = strcat(folder,'VHDL_report.log');

fout = fopen(filename, 'w');

fprintf(fout,'                        CIRCUIT INFORMATION REPORT\n');
fprintf(fout,'___________________________________________________________________________\n\n');
fprintf(fout,'Target device: FPGA\n');
fprintf(fout,'Circuit architecture: %s\n',optout.architecture);
fprintf(fout,'___________________________________________________________________________\n\n');
fprintf(fout,'Inputs:\n');
fprintf(fout,'\t - Resolution: %d bits\n',optout.inputResolution);
fprintf(fout,'\t - Representation: fixed point %s\n',optout.inputRepresentation);
fprintf(fout,'\t - Range (model --> circuit):\n');
for i = 1:ndim
    fprintf(fout,'\t\t%s: [%f %f] --> x%d: [%d %d]\n',object.xnames{i},...
        range.xmin(i),range.xmax(i),i,range.xmin_cir(i),range.xmax_cir(i));
end
fprintf(fout,'\nOutputs:\n');
fprintf(fout,'\t - Resolution: %d bits\n',optout.outputResolution);
fprintf(fout,'\t - Representation: fixed point %s\n',optout.outputRepresentation);
fprintf(fout,'\t - Range (model --> circuit):\n');
for i = 1:nfun
    fprintf(fout,'\t\t%s: [%f %f] --> y%d: [%d %d]\n',object.ynames{idx(i)},...
        range.umin(i),range.umax(i),i,range.umin_cir(i),range.umax_cir(i));
end
fprintf(fout,'\nCoefficients:\n');
fprintf(fout,'\t - Resolution: %d bits\n',optout.coeffResolution);
fprintf(fout,'\t - Representation: fixed point signed\n');
fprintf(fout,'___________________________________________________________________________\n\n');
fprintf(fout,'Timings:\r\n');
if optout.frequency < 1000
    fprintf(fout,'\t - Workin1g frequency = %f Hz\n',optout.frequency);
elseif optout.frequency < 1000000
    fprintf(fout,'\t - Working frequency = %f kHz\n',optout.frequency/1e3);
else
    fprintf(fout,'\t - Working frequency = %f MHz\n',optout.frequency/1e6);
end

time = latency/optout.frequency;

if time > 1
    fprintf(fout,'\t - Latency = %.2f s (%d clock cycles)\n',time,latency);
elseif time > 1e-3
    fprintf(fout,'\t - Latency = %.2f ms (%d clock cycles)\n',time*1e3,latency);
elseif time > 1e-6
    fprintf(fout,'\t - Latency = %.2f us (%d clock cycles)\n',time*1e6,latency);
else
    fprintf(fout,'\t - Latency = %.2f ns (%d clock cycles)\n',time*1e9,latency);
end
fprintf(fout,'___________________________________________________________________________\n\n');
fprintf(fout,'Resources:\n');
fprintf(fout,'\t - Multiplier(s) = %d (%d x %d bits)\n',multipliers,nbit_mul,nbit_mul);
fprintf(fout,'___________________________________________________________________________\n\n');
fprintf(fout,'Memory size:\n');
fprintf(fout,'\t - Number of cells = %d\n',memory_size);
fprintf(fout,'\t - Word size = %d bits\n',nbit_coeff);
fprintf(fout,'\t - Total occupation = %.3f bytes\n',nbit_coeff*memory_size/8);
fclose(fout);

if nargout == 0
    edit([folder ,'VHDL_report.log'])
end

