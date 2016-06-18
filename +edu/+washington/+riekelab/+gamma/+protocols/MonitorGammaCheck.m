classdef MonitorGammaCheck < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        amp
        preTime = 500                   % Pulse leading duration (ms)
        stimTime = 750                  % Pulse duration (ms)
        tailTime = 500                  % Pulse trailing duration (ms)
    end
    
    properties
        numSteps = uint16(16)           % Number of steps of intensity to measure
    end
    
    properties (Hidden, Transient)
        ampType
        currentStep
        outputs
        measurements
        optometer
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice('Optometer'));
            handler = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.updateGammaTable);
            
            % Create gamma table figure
            if ~isfield(handler.userData, 'axesHandle')
                h = handler.getFigureHandle();
                t = 'Optometer Power Measurement vs. Intensity';
                set(h, 'Name', t);
                a = axes(h, ...
                    'FontName', get(h, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(h, 'DefaultUicontrolFontSize'));
                title(a, t);
                xlabel(a, 'Output (inten.)');
                ylabel(a, 'Power (uW)');
                set(a, 'Box', 'off', 'TickDir', 'out');
                handler.userData.axesHandle = a;
                handler.userData.gammaLineHandle = line(0, 0, 'Parent', a);
            end
            
            % Create output intensities that grow from 0 to 1.
            obj.outputs = linspace(0, 1, obj.numSteps);
            
            obj.currentStep = 1;
            obj.measurements = zeros(1, obj.numSteps);
            
            obj.optometer = edu.washington.riekelab.gamma.OptometerUDT350();
        end
        
        function updateGammaTable(obj, handler, epoch)
            response = epoch.getResponse(obj.rig.getDevice('Optometer'));
            quantities = response.getData();
            quantities = quantities * 1e3; % V to mV
            
            prePts = round(obj.preTime / 1e3 * obj.sampleRate);
            stimPts = round(obj.stimTime / 1e3 * obj.sampleRate);
            measurementStart = prePts + (stimPts / 2);
            measurementEnd = prePts + stimPts;
            
            baseline = mean(quantities(1:prePts));
            measurement = mean(quantities(measurementStart:measurementEnd));
            
            % Change gain, if necessary.
            outputMax = obj.optometer.OUTPUT_MAX;
            outputMin = obj.optometer.OUTPUT_MAX / obj.optometer.GAIN_STEP_MULTIPLIER;
            outputMin = outputMin * 0.8;
            
            if measurement > outputMax && obj.optometer.gain < obj.optometer.GAIN_MAX
                obj.optometer.increaseGain();
                return;
            elseif measurement < outputMin && obj.optometer.gain > obj.optometer.GAIN_MIN
                obj.optometer.decreaseGain();
                return;
            end
            
            % No gain adjustments were required, we can now record the measured intensity.
            obj.measurements(obj.currentStep) = (measurement - baseline) * obj.optometer.MICROWATT_PER_MILLIVOLT * obj.optometer.gain;
            
            set(handler.userData.gammaLineHandle, 'Xdata', obj.outputs(1:obj.currentStep), 'Ydata', obj.measurements(1:obj.currentStep));
            
            axesHandle = handler.userData.axesHandle;
            xlim(axesHandle, [min(obj.outputs(1:obj.currentStep)) - 0.05, max(obj.outputs(1:obj.currentStep)) + 0.05]);
            ylim(axesHandle, [min(obj.measurements) - 0.05, max(obj.measurements) + 0.05]);
            
            obj.currentStep = obj.currentStep + 1;
        end
        
        function p = createPresentation(obj)
            device = obj.rig.getDevice('Stage');
            canvasSize = device.getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(0);
            
            rect = stage.builtin.stimuli.Rectangle();
            rect.position = canvasSize / 2;
            rect.size = [300, 300];
            rect.color = obj.outputs(obj.currentStep);
            p.addStimulus(rect);
            
            rectVisible = stage.builtin.controllers.PropertyController(rect, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(rectVisible);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(obj.rig.getDevice('Optometer'));
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.shouldContinueRun();
        end        
        
        function tf = shouldContinueRun(obj)
            tf = obj.currentStep <= obj.numSteps;
        end
        
        function completeRun(obj)
            completeRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            if obj.currentStep > obj.numSteps
                % Normalize measurements with span from 0 to 1.
                mrange = max(obj.measurements) - min(obj.measurements);
                baseline = min(obj.measurements);
                
                outs = obj.outputs;
                values = (obj.measurements - baseline) / mrange;
                
                % Create ideal linear gamma vector.
                linear = linspace(0, 1, 256);
                
                h = figure('Name', 'Gamma', 'NumberTitle', 'off');
                a = axes(h);
                plot(a, outs, values, '.', ((0:255)/255), linear, '-');
                legend(a, 'Measurements', 'Ideal');
                title(a, 'Gamma');
                set(a, ...
                    'FontName', get(h, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(h, 'DefaultUicontrolFontSize'));
            end
        end
        
        function [tf, msg] = isValid(obj)
            [tf, msg] = isValid@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            if tf
                tf = ~isempty(obj.rig.getDevices('Optometer'));
                msg = 'No optometer';
            end
        end
        
    end
    
end

