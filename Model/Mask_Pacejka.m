classdef Mask_Pacejka

    methods(Static)

        % Following properties of 'maskInitContext' are avalaible to use:
        %  - BlockHandle 
        %  - MaskObject 
        %  - MaskWorkspace: Use get/set APIs to work with mask workspace.
        function MaskInitialization(maskInitContext)
            set_param(maskInitContext.BlockHandle, 'FunctionName', 'TirePacejka');
            r_p            = maskInitContext.MaskWorkspace.get('r_p');
            l_am           = maskInitContext.MaskWorkspace.get('l_am');
            l_f            = maskInitContext.MaskWorkspace.get('l_f');
            Bf             = maskInitContext.MaskWorkspace.get('Bf');
            Cf             = maskInitContext.MaskWorkspace.get('Cf');
            Df             = maskInitContext.MaskWorkspace.get('Df');
            Ef             = maskInitContext.MaskWorkspace.get('Ef');
            K_torque_ratio = maskInitContext.MaskWorkspace.get('K_torque_ratio');
        
            set_param(maskInitContext.BlockHandle, 'Parameters', ...
                sprintf('%.15g,%.15g,%.15g,%.15g,%.15g,%.15g,%.15g,%.15g', ...
                    r_p, l_am, l_f, Bf, Cf, Df, Ef, K_torque_ratio));
        end

        % Use the code browser on the left to add the callbacks.

    end
end