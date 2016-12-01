classdef TwoPhotonWithMicrodisplayAboveAndOptometer < edu.washington.riekelab.rigs.TwoPhotonWithMicrodisplayAbove
    
    methods
        
        function obj = TwoPhotonWithMicrodisplayAboveAndOptometer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            optometer = UnitConvertingDevice('Optometer', 'V').bindStream(daq.getStream('ai1'));
            obj.addDevice(optometer);  
        end
        
    end
    
end

