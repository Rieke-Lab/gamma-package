classdef OldSliceWithMicrodisplayAndOptometer < edu.washington.riekelab.rigs.OldSliceWithMicrodisplay
    
    methods
        
        function obj = OldSliceWithMicrodisplayAndOptometer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            optometer = UnitConvertingDevice('Optometer', 'V').bindStream(daq.getStream('ANALOG_IN.1'));
            obj.addDevice(optometer);  
        end
        
    end
    
end

