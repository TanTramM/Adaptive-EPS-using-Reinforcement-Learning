classdef untitled

    methods(Static)

        % Following properties of 'maskInitContext' are avalaible to use:
        %  - BlockHandle 
        %  - MaskObject 
        %  - MaskWorkspace: Use get/set APIs to work with mask workspace.
        function MaskInitialization(maskInitContext)
          J_total   = maskInitContext.MaskWorkspace.getParameter('J_total');
B_total   = maskInitContext.MaskWorkspace.getParameter('B_total');
T_f_total = maskInitContext.MaskWorkspace.getParameter('T_f_total');

set_param(maskInitContext.BlockHandle, 'Parameters', ...
    mat2str([J_total, B_total, T_f_total]));  
        end

        % Following properties of 'maskInitContext' are avalaible to use:
        %  - BlockHandle 
        %  - MaskObject 
        %  - MaskWorkspace: Use get/set APIs to work with mask workspace.
        

        % Use the code browser on the left to add the callbacks.

    end
end