classdef Mask_SC
    methods(Static)

        % Following properties of 'maskInitContext' are avalaible to use:
        %  - BlockHandle 
        %  - MaskObject  
        %  - MaskWorkspace: Use get/set APIs to work with mask workspace.
        function MaskInitialization(maskInitContext)
            set_param(maskInitContext.BlockHandle, 'FunctionName', 'SteeringColumn');
            J_total   = maskInitContext.MaskWorkspace.get('J_total');
            B_total   = maskInitContext.MaskWorkspace.get('B_total');
            T_f_total = maskInitContext.MaskWorkspace.get('T_f_total');
        
            set_param(maskInitContext.BlockHandle, 'Parameters', sprintf('%.15g,%.15g,%.15g', J_total, B_total, T_f_total));
        end

        % Use the code browser on the left to add the callbacks.

    end
end

