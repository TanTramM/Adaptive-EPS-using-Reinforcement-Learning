classdef Mask_bike

    methods(Static)

        % Following properties of 'maskInitContext' are avalaible to use:
        %  - BlockHandle 
        %  - MaskObject 
        %  - MaskWorkspace: Use get/set APIs to work with mask workspace.
        function MaskInitialization(maskInitContext)
            set_param(maskInitContext.BlockHandle, 'FunctionName', 'VehicleDynamics');
        
            m   = maskInitContext.MaskWorkspace.get('m');
            l_f = maskInitContext.MaskWorkspace.get('l_f');
            l_r = maskInitContext.MaskWorkspace.get('l_r');
            C_r = maskInitContext.MaskWorkspace.get('C_r');
            I_z = maskInitContext.MaskWorkspace.get('I_z');
        
            set_param(maskInitContext.BlockHandle, 'Parameters', ...
                sprintf('%.15g,%.15g,%.15g,%.15g,%.15g', m, l_f, l_r, C_r, I_z));
        end

        % Use the code browser on the left to add the callbacks.

    end
end