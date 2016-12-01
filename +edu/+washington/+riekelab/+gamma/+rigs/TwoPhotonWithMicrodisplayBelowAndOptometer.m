classdef TwoPhotonWithMicrodisplayBelowAndOptometer < edu.washington.riekelab.rigs.TwoPhotonWithMicrodisplayBelow
    
    methods
        
        function obj = TwoPhotonWithMicrodisplayBelowAndOptometer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            optometer = UnitConvertingDevice('Optometer', 'V').bindStream(daq.getStream('ai1'));
            obj.addDevice(optometer);  
        end
        
    end
    
end

