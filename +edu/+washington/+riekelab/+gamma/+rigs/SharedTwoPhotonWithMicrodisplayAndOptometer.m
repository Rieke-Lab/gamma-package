classdef SharedTwoPhotonWithMicrodisplayAndOptometer < edu.washington.riekelab.rigs.SharedTwoPhotonWithMicrodisplay
    
    methods
        
        function obj = SharedTwoPhotonWithMicrodisplayAndOptometer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            optometer = UnitConvertingDevice('Optometer', 'V').bindStream(daq.getStream('ai1'));
            obj.addDevice(optometer);  
        end
        
    end
    
end

