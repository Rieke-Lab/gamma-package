classdef ConfocalWithMicrodisplayAndOptometer < edu.washington.riekelab.rigs.ConfocalWithMicrodisplay
    
    methods
        
        function obj = ConfocalWithMicrodisplayAndOptometer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            optometer = UnitConvertingDevice('Optometer', 'V').bindStream(daq.getStream('ANALOG_IN.1'));
            obj.addDevice(optometer);  
        end
        
    end
    
end

