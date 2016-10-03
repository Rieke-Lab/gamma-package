classdef SuctionWithOptometer < edu.washington.riekelab.rigs.Suction
    
    methods
        
        function obj = SuctionWithOptometer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            optometer = UnitConvertingDevice('Optometer', 'V').bindStream(daq.getStream('ai1'));
            obj.addDevice(optometer);  
        end
        
    end
    
end

