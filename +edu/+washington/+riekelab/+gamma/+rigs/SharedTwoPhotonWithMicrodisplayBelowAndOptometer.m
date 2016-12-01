classdef SharedTwoPhotonWithMicrodisplayBelowAndOptometer < edu.washington.riekelab.rigs.SharedTwoPhotonWithMicrodisplayBelow
    
    methods
        
        function obj = SharedTwoPhotonWithMicrodisplayBelowAndOptometer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            optometer = UnitConvertingDevice('Optometer', 'V').bindStream(daq.getStream('ai1'));
            obj.addDevice(optometer);  
        end
        
    end
    
end

