classdef LedGammaCheck < edu.washington.riekelab.protocols.RiekeLabProtocol

    properties
        led                             % Output LED
        preTime = 500                   % Pulse leading duration (ms)
        stimTime = 750                  % Pulse duration (ms)
        tailTime = 500                  % Pulse trailing duration (ms)
        calibrationIntensity = 0.1      % Intensity to measure a value to check against (norm. [0-1])
        acceptableError = 0.05          % Acceptable error from calibration intensity measurement (ratio)
    end

    properties (Constant)
        numSteps = 11                   % Number of steps of intensity to measure
        firstStep = 0.001               % Starting step intensity value
    end

    properties (Hidden)
        ledType
        currentStep
        outputs
        measurements
        predictions
        failures
        optometer
    end

    methods

        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);

            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice('Optometer'));
            handler = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.updateGammaTable);

            % Create gamma table figure
            if ~isfield(handler.userData, 'axesHandle')
                h = handler.getFigureHandle();
                t = ['Optometer Power Measurement vs. ' obj.led ' Intensity'];
                set(h, 'Name', t);
                a = axes(h, ...
                    'FontUnits', get(h, 'DefaultUicontrolFontUnits'), ...
                    'FontName', get(h, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(h, 'DefaultUicontrolFontSize'));
                title(a, t);
                xlabel(a, 'Intensity (normalized)');
                ylabel(a, 'Power (uW)');
                set(a, 'Box', 'off', 'TickDir', 'out');
                handler.userData.axesHandle = a;
            end

            % Create output intensities that grow exponentially from the first step up to the max intensity (1)
            outs = 2.^(1:obj.numSteps)';
            outs = (outs - min(outs)) / (max(outs) - min(outs));
            outs = (outs * (1 - obj.firstStep)) + obj.firstStep;
            obj.outputs = outs;

            % Step 0 will be a baseline measurement.
            obj.currentStep = 0;

            obj.measurements = zeros(obj.numSteps, 1);
            obj.failures = [];

            device = obj.rig.getDevice(obj.led);
            if ~isprop(device, 'measurementConversionTarget') ...
                    || ~strcmp(device.measurementConversionTarget, symphonyui.core.Measurement.NORMALIZED) ...
                    || ~isprop(device.cobj, 'LookupTable')
                error([obj.led ' must use normalized units and have an associated lookup table to use this protocol']);
            end

            device.background = symphonyui.core.Measurement(0, device.background.displayUnits);

            obj.optometer = edu.washington.riekelab.gamma.OptometerUDT350(10^0);
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

            % No gain adjustments are required.
            intensity = (measurement - baseline) * obj.optometer.MICROWATT_PER_MILLIVOLT * obj.optometer.gain;

            if obj.currentStep == 0
                % Calculate a predicted intensity for each output value.
                obj.predictions = zeros(obj.numSteps, 1);
                for i = 1:obj.numSteps
                    obj.predictions(i) = intensity * obj.outputs(i) / obj.calibrationIntensity;
                end

                % Turn down the optometer gain to start verification.
                obj.optometer.gain = 10^-1;
                obj.currentStep = obj.currentStep + 1;
                return;
            end

            obj.measurements(obj.currentStep) = intensity;

            lower = obj.predictions(obj.currentStep) - (obj.predictions(obj.currentStep) * obj.acceptableError);
            upper = obj.predictions(obj.currentStep) + (obj.predictions(obj.currentStep) * obj.acceptableError);

            if obj.measurements(obj.currentStep) < lower || obj.measurements(obj.currentStep) > upper
                obj.failures(end + 1, 1) = obj.outputs(obj.currentStep);
                obj.failures(end, 2) = obj.measurements(obj.currentStep);
            end

            errors = obj.predictions(1:obj.currentStep) * obj.acceptableError;

            axesHandle = handler.userData.axesHandle;
            t = get(get(axesHandle, 'Title'), 'String');
            x = get(get(axesHandle, 'XLabel'), 'String');
            y = get(get(axesHandle, 'YLabel'), 'String');

            errorbar(obj.outputs(1:obj.currentStep), obj.predictions(1:obj.currentStep), errors, 'Parent', axesHandle, 'LineStyle', 'none', 'Marker', 's', 'Color', 'g');

            set(axesHandle, ...
                'FontUnits', get(handler.getFigureHandle(), 'DefaultUicontrolFontUnits'), ...
                'FontName', get(handler.getFigureHandle(), 'DefaultUicontrolFontName'), ...
                'FontSize', get(handler.getFigureHandle(), 'DefaultUicontrolFontSize'));
            title(axesHandle, t);
            xlabel(axesHandle, x);
            ylabel(axesHandle, y);

            line(obj.outputs(1:obj.currentStep), obj.measurements(1:obj.currentStep), 'Parent', axesHandle, 'LineStyle', 'none', 'Marker', 'o', 'Color', 'b');

            if isempty(obj.failures)
                legend(axesHandle, {'Predicted', 'Measured'}, 'Parent', handler.getFigureHandle());
            else
                line(obj.failures(:,1), obj.failures(:,2), 'Parent', axesHandle, 'LineStyle', 'none', 'LineWidth', 2, 'Marker', 'x', 'MarkerSize', 12,  'Color', 'r');
                legend(axesHandle, {'Predicted', 'Measured', 'Failed'}, 'Parent', handler.getFigureHandle());
            end

            xlim(axesHandle, [min(obj.outputs(1:obj.currentStep)) - 1e-4, max(obj.outputs(1:obj.currentStep)) + 1e-4]);
            ylim(axesHandle, [min(obj.measurements) - 0.01, max(obj.measurements) + 0.01]);

            obj.currentStep = obj.currentStep + 1;
        end

        function stim = createLedStimulus(obj, step)
            if obj.currentStep == 0
                output = obj.calibrationIntensity;
            else
                output = obj.outputs(step);
            end

            gen = symphonyui.builtin.stimuli.PulseGenerator();

            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = output;
            gen.mean = 0;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;

            stim = gen.generate();
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);

            epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus(obj.currentStep));
            epoch.addResponse(obj.rig.getDevice('Optometer'));
        end

        function tf = shouldContinuePreloadingEpochs(obj) %#ok<MANU>
            tf = false;
        end

        function tf = shouldWaitToContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared > obj.numEpochsCompleted || obj.numIntervalsPrepared > obj.numIntervalsCompleted;
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.shouldContinueRun();
        end

        function tf = shouldContinueRun(obj)
            tf = obj.currentStep <= obj.numSteps;
        end

        function [tf, msg] = isValid(obj)
            [tf, msg] = isValid@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            if tf
                tf = ~isempty(obj.rig.getDevices('Optometer'));
                msg = 'No optometer';
            end
        end

    end

end
