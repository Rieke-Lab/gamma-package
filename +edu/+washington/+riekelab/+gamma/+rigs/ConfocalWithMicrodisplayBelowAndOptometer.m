classdef ConfocalWithMicrodisplayBelowAndOptometer < edu.washington.riekelab.rigs.ConfocalWithMicrodisplayBelow
    
    methods
        
        function obj = ConfocalWithMicrodisplayBelowAndOptometer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            optometer = UnitConvertingDevice('Optometer', 'V').bindStream(daq.getStream('ai1'));
            obj.addDevice(optometer);  
        end
        
    end
    
end

