classdef LedGammaMeasurement < edu.washington.riekelab.protocols.RiekeLabProtocol

    properties
        led                             % Output LED
        preTime = 500                   % Pulse leading duration (ms)
        stimTime = 750                  % Pulse duration (ms)
        tailTime = 500                  % Pulse trailing duration (ms)
    end

    properties (Constant)
        numSteps = 100                  % Number of steps of intensity to measure
        zeroOffset = -0.0005            % Starting step intensity value
    end

    properties (Hidden)
        ledType
        currentStep
        outputs
        measurements
        optometer
        lookupTable
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
                handler.userData.gammaLineHandle = line(0, 0, 'Parent', a);
            end

            % Create output intensities that grow exponentially from zero offset to 1
            outs = 1.05.^(1:obj.numSteps)';
            outs = (outs - min(outs)) / (max(outs) - min(outs));
            outs = (outs * (1 - obj.zeroOffset)) + obj.zeroOffset;
            obj.outputs = outs;

            obj.currentStep = 1;
            obj.measurements = zeros(obj.numSteps, 1);

            % Store the current lookup table
            device = obj.rig.getDevice(obj.led);
            if ~isprop(device, 'measurementConversionTarget') ...
                    || ~strcmp(device.measurementConversionTarget, symphonyui.core.Measurement.NORMALIZED) ...
                    || ~isprop(device.cobj, 'LookupTable')
                error([obj.led ' must use normalized units and have an associated lookup table to use this protocol']);
            end
            obj.lookupTable = device.cobj.LookupTable;

            % Set a linear lookup table
            lut = NET.createGeneric('System.Collections.Generic.SortedList', {'System.Decimal', 'System.Decimal'});
            lut.Add(obj.zeroOffset, obj.zeroOffset);
            lut.Add(1, 1);
            device.cobj.LookupTable = lut;

            device.background = symphonyui.core.Measurement(obj.zeroOffset, device.background.displayUnits);

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

        function stim = createLedStimulus(obj, step)
            gen = symphonyui.builtin.stimuli.PulseGenerator();

            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.outputs(step) - obj.zeroOffset;
            gen.mean = obj.zeroOffset;
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

        function completeRun(obj)
            completeRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);

            % Restore old lookup table
            device = obj.rig.getDevice(obj.led);
            if isprop(device.cobj, 'LookupTable') && ~isempty(obj.lookupTable)
                obj.rig.getDevice(obj.led).cobj.LookupTable = obj.lookupTable;
            end

            if obj.currentStep > obj.numSteps
                % Save the gamma table

                % Normalize measurements with span from 0 to 1
                mrange = max(obj.measurements) - min(obj.measurements);
                baseline = min(obj.measurements);
                xRamp = (obj.measurements - baseline) / mrange;
                yRamp = obj.outputs;

                ramp = [xRamp, yRamp]; %#ok<NASGU>

                % Save the ramp to file
                [filename, pathname] = uiputfile('*.txt', 'Save Gamma Table');
                if ~isequal(filename, 0) && ~isequal(pathname, 0)
                    save(fullfile(pathname, filename), 'ramp', '-ascii', '-tabs');
                end
            end
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
