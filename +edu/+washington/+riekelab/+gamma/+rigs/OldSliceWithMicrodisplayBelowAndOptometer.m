classdef OldSliceWithMicrodisplayBelowAndOptometer < edu.washington.riekelab.rigs.OldSliceWithMicrodisplayBelow
    
    methods
        
        function obj = OldSliceWithMicrodisplayBelowAndOptometer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            optometer = UnitConvertingDevice('Optometer', 'V').bindStream(daq.getStream('ai1'));
            obj.addDevice(optometer);  
        end
        
    end
    
end

