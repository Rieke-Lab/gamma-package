classdef SharedTwoPhotonWithOptometer < edu.washington.riekelab.rigs.SharedTwoPhoton
    
    methods
        
        function obj = SharedTwoPhotonWithOptometer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            optometer = UnitConvertingDevice('Optometer', 'V').bindStream(daq.getStream('ai1'));
            obj.addDevice(optometer);  
        end
        
    end
    
end

