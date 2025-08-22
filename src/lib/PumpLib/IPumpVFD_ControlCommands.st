INTERFACE IPumpVFD_ControlCommands EXTENDS BasicControlCommands

    METHOD Start_VFD
    VAR_INPUT
        access : BOOL;
        device : IPumpVFD_Control;
    END_VAR

    METHOD Stop_VFD
    VAR_INPUT
        access: BOOL;
        device : IPumpVFD_Control;
    END_VAR

    METHOD SwitchToStart
    VAR_INPUT
        access : BOOL;
        device : IPumpVFD_Control;
    END_VAR
    METHOD SwitchToVFD
    VAR_INPUT
        access : BOOL;
        device : IPumpVFD_Control;
    END_VAR
    