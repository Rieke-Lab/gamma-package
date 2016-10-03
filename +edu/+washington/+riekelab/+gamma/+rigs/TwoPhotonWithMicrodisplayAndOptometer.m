classdef TwoPhotonWithMicrodisplayAndOptometer < edu.washington.riekelab.rigs.TwoPhotonWithMicrodisplay
    
    methods
        
        function obj = TwoPhotonWithMicrodisplayAndOptometer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            optometer = UnitConvertingDevice('Optometer', 'V').bindStream(daq.getStream('ai1'));
            obj.addDevice(optometer);  
        end
        
    end
    
end

