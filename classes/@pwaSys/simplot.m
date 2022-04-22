function signals = simplot(object,T,x0,varargin)
% simplot    Simulates the dynamical system and plots results
%
% Performs a simulation by means of method ltiSys/sim and plots the
% results. The syntax is the same of method ltiSys/sim.
% SIGNALS = simplot(OBJ,T,X0)
% SIGNALS = simplot(OBJ,T,X0,OPTS)
% SIGNALS = simplot(OBJ,T,X0,REF)
% SIGNALS = simplot(OBJ,T,X0,REF,OPTS)
% SIGNALS = simplot(OBJ,T,X0,P,D,REF)
% SIGNALS = simplot(OBJ,T,X0,P,D,REF,OPTS)
%
% OPTS can also have a field OPTS.constraints containing a "constraints" 
% object. If OPTS.constraints is provided, the constraints are plotted in
% order to visually check if they are fulfilled. Hard constraints are 
% plotted with solid black lines, soft constraints with dashed black lines.
%
% See also: ltiSys/sim.

% Contributors:
%
% Alberto Oliveri (alberto.oliveri@unige.it)
%
% Copyright (C) 2015 University of Genoa, Italy.

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

if isempty(varargin)
    signals = object.sim(T,x0);
else
    signals = object.sim(T,x0,varargin{:});
end

options = [];

if nargin == 4
    if isstruct(varargin{1})
        p = [];
        d = [];
        ref = [];
        options = varargin{1};
    end
elseif nargin == 5
    if isstruct(varargin{2})
        options = varargin{2};
    end
elseif nargin == 6
    if isstruct(varargin{3})
        options = varargin{3};
    end
elseif nargin == 7
    options = varargin{4};    
end

if isfield(options,'constraints')
    constr = options.constraints;
else
    constr = [];
end

if ~isempty(constr) && ~isa(constr,'constraints')
    error('OPTS.constraints must be a ''constraints'' object');
end

% Retrieve names
xnames = object.getStateNames();
unames = object.getInputNames();
ynames = object.getOutputNames();
dnames = object.getUnmeasurableInputNames();


% Number of states, inputs and outputs
nx = object.nx;
nu = object.nu;
ny = object.ny;
nd = object.nd;

if ~isempty(signals.time)
    
    if object.isContinuousTime
        
        % Extract constraints matrices at following time instant
        if ~isempty(constr)
            [H, K] = constr.getAllConstraints('hard',1);
            [Hs, Ks] = constr.getAllConstraints('soft',1);
        end
        
        % Plot states
        figure('Name','System states')
        for i = 1:nx
            subplot(nx,1,i)
            
            if ~isempty(constr)
                Hleft = H(:,i);
                Hright = H(:,setdiff(1:size(H,2),i));
                idx = Hleft~=0;
                Hleft = Hleft(idx);
                if ~isempty(Hleft)
                    Hright = Hright(idx,:);
                    Kright = K(idx);
                    npts = numel(signals.time);
                    plot(signals.time,(repmat(Kright',npts,1)-...
                        [signals.state(:,setdiff(1:nx,i)) signals.input...
                        signals.parameter signals.unmeasurable_input]*Hright')./...
                        repmat(Hleft',npts,1),'k')
                end
                Hsleft = Hs(:,i);
                Hsright = Hs(:,setdiff(1:size(Hs,2),i));
                idx = Hsleft~=0;
                Hsleft = Hsleft(idx);
                if ~isempty(Hsleft)
                    Hsright = Hsright(idx,:);
                    Ksright = Ks(idx);
                    npts = numel(signals.time);
                    plot(signals.time,(repmat(Ksright',npts,1)-...
                        [signals.state(:,setdiff(1:nx,i)) signals.input...
                        signals.parameter signals.unmeasurable_input]*Hsright')./...
                        repmat(Hsleft',npts,1),'--k')
                end
            end
            
            hold on
            plot(signals.time,signals.state(:,i),'b')
            if object.hasObserver()
                plot(signals.time,signals.est_state(:,i),'r')
                legend('real','estimated')
            end
            if object.hasController
                ctrl = object.getController();
                if ctrl.isTracking
                    trackvar = ctrl.getTrackingVariable();
                    idx = find(trackvar == i);
                    if ~isempty(idx)
                        plot([signals.time(1) signals.time(end)],[signals.ref(idx) signals.ref(idx)],'c')
                    end
                end
            end
            xlabel('t')
            ylabel(xnames{i})
            grid on
        end
        
        % Plot unmeasurable inputs
        if object.hasObserver()
            if object.nd > 0
                figure('Name','Unmeasurable inputs')
                for i = 1:nd
                    subplot(nd,1,i)
                    hold on
                    plot([signals.time(1) signals.time(end)],...
                        [signals.unmeasurable_input(i) signals.unmeasurable_input(i)],'b')
                    plot(signals.time,signals.est_state(:,nx+i),'r')
                    xlabel('t')
                    ylabel(dnames{i})
                    grid on
                end
            end
        end
        
        % Extract constraints matrices at current time instant
        if ~isempty(constr)
            [H, K] = constr.getAllConstraints('hard',0);
            [Hs, Ks] = constr.getAllConstraints('soft',0);
        end
        
        % Plot inputs
        figure('Name','System inputs')       
        for i = 1:nu
            subplot(nu+1,1,i)
            hold on
            
            if ~isempty(constr)
                Hleft = H(:,nx+i);
                Hright = H(:,setdiff(1:size(H,2),nx+i));
                idx = Hleft~=0;
                Hleft = Hleft(idx);
                if ~isempty(Hleft)
                    Hright = Hright(idx,:);
                    Kright = K(idx);
                    npts = numel(signals.time);
                    plot(signals.time,(repmat(Kright',npts,1)-...
                        [signals.state signals.input(:,setdiff(1:nu,i))...
                        signals.parameter signals.unmeasurable_input]*Hright')./...
                        repmat(Hleft',npts,1),'k')
                end
                Hsleft = Hs(:,nx+i);
                Hsright = Hs(:,setdiff(1:size(Hs,2),nx+i));
                idx = Hsleft~=0;
                Hsleft = Hsleft(idx);
                if ~isempty(Hsleft)
                    Hsright = Hsright(idx,:);
                    Ksright = Ks(idx);
                    npts = numel(signals.time);
                    plot(signals.time,(repmat(Ksright',npts,1)-...
                        [signals.state signals.input(:,setdiff(1:nu,i))...
                        signals.parameter signals.unmeasurable_input]*Hsright')./...
                        repmat(Hsleft',npts,1),'--k')
                end
            end
            
            
            plot(signals.time,signals.input(:,i),'b')
            xlabel('t')
            ylabel(unames{i})
            grid on
        end
        
        % Plot dynamics
        subplot(nu+1,1,nu+1)
        stairs(signals.time,signals.dynamics,'b')
            xlabel('t')
            ylabel('Dynamics')
            grid on
        
        % Plot outputs
        figure('Name','System outputs')
        for i = 1:ny
            subplot(ny,1,i)
            hold on
            plot(signals.time,signals.output(:,i),'b')
            if object.hasObserver()
                plot(signals.time,signals.est_output(:,i),'r')
                legend('real','estimated')
            end
            xlabel('t')
            ylabel(ynames{i})
            grid on
        end
        
    else
        
        % Extract constraints matrices at following time instant
        if ~isempty(constr)
            [H, K] = constr.getAllConstraints('hard',1);
            [Hs, Ks] = constr.getAllConstraints('soft',1);
        end
        
        % Plot states
        figure('Name','System states')
        for i = 1:nx
            subplot(nx,1,i)
            hold on
            
            if ~isempty(constr)
                Hleft = H(:,i);
                Hright = H(:,setdiff(1:size(H,2),i));
                idx = Hleft~=0;
                Hleft = Hleft(idx);
                if ~isempty(Hleft)
                    Hright = Hright(idx,:);
                    Kright = K(idx);
                    npts = numel(signals.time);
                    stairs(signals.time,(repmat(Kright',npts,1)-...
                        [signals.state(:,setdiff(1:nx,i)) signals.input...
                        signals.parameter signals.unmeasurable_input]*Hright')./...
                        repmat(Hleft',npts,1),'k')
                end
                Hsleft = Hs(:,i);
                Hsright = Hs(:,setdiff(1:size(Hs,2),i));
                idx = Hsleft~=0;
                Hsleft = Hsleft(idx);
                if ~isempty(Hsleft)
                    Hsright = Hsright(idx,:);
                    Ksright = Ks(idx);
                    npts = numel(signals.time);
                    stairs(signals.time,(repmat(Ksright',npts,1)-...
                        [signals.state(:,setdiff(1:nx,i)) signals.input...
                        signals.parameter signals.unmeasurable_input]*Hsright')./...
                        repmat(Hsleft',npts,1),'--k')
                end
            end
            
            stairs(signals.time,signals.state(:,i),'b')
            if object.hasObserver()
                stairs(signals.time,signals.est_state(:,i),'r')
                legend('real','estimated')
            end
            xlabel('t')
            ylabel(xnames{i})
            grid on
        end
        
        % Plot unmeasurable inputs
        if object.hasObserver()
            figure('Name','Unmeasurable inputs')
            for i = 1:nd
                subplot(nd,1,i)
                hold on
                plot([signals.time(1) signals.time(end)],...
                    [signals.unmeasurable_input(i) signals.unmeasurable_input(i)],'b')
                plot(signals.time,signals.est_state(:,nx+i),'r')
                xlabel('t')
                ylabel(dnames{i})
                grid on
            end
        end
        
        % Extract constraints matrices at current time instant
        if ~isempty(constr)
            [H, K] = constr.getAllConstraints('hard',0);
            [Hs, Ks] = constr.getAllConstraints('soft',0);
        end
        
        % Plot inputs
        figure('Name','System inputs')
        for i = 1:nu
            subplot(nu+1,1,i)
            hold on
            
            if ~isempty(constr)
                Hleft = H(:,nx+i);
                Hright = H(:,setdiff(1:size(H,2),nx+i));
                idx = Hleft~=0;
                Hleft = Hleft(idx);
                if ~isempty(Hleft)
                    Hright = Hright(idx,:);
                    Kright = K(idx);
                    npts = numel(signals.time);
                    stairs(signals.time,(repmat(Kright',npts,1)-...
                        [signals.state signals.input(:,setdiff(1:nu,i))...
                        signals.parameter signals.unmeasurable_input]*Hright')./...
                        repmat(Hleft',npts,1),'k')
                end
                Hsleft = Hs(:,nx+i);
                Hsright = Hs(:,setdiff(1:size(Hs,2),nx+i));
                idx = Hsleft~=0;
                Hsleft = Hsleft(idx);
                if ~isempty(Hsleft)
                    Hsright = Hsright(idx,:);
                    Ksright = Ks(idx);
                    npts = numel(signals.time);
                    stairs(signals.time,(repmat(Ksright',npts,1)-...
                        [signals.state signals.input(:,setdiff(1:nu,i))...
                        signals.parameter signals.unmeasurable_input]*Hsright')./...
                        repmat(Hsleft',npts,1),'k')
                end
            end
            
            stairs(signals.time,signals.input(:,i),'b')
            xlabel('t')
            ylabel(unames{i})
            grid on
        end
        
        % Plot dynamics
        subplot(nu+1,1,nu+1)
        stairs(signals.time,signals.dynamics,'b')
            xlabel('t')
            ylabel('Dynamics')
            grid on
        
        % Plot outputs
        figure('Name','System outputs')
        for i = 1:ny
            subplot(ny,1,i)
            hold on
            stairs(signals.time,signals.output(:,i),'b')
            if object.hasObserver()
                stairs(signals.time,signals.est_output(:,i),'r')
                legend('real','estimated')
            end
            xlabel('t')
            ylabel(ynames{i})
            grid on
        end
        
    end
    
    if object.hasController
        
        ctrl = object.getController();
        ndim = ctrl.getNumberOfDimensions;
        
        % Domain dimensions of the controller
        
        if ndim == 2
            object.controller.plotPartition();
            hold on
            plot(signals.state(:,1),signals.state(:,2),'k','linewidth',2)
            if object.hasObserver()
                plot(signals.est_state(:,1),signals.est_state(:,2),'--k','linewidth',2)
            end
        end
    end
    
    
    
end
