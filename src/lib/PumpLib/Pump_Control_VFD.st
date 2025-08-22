FUNCTION_BLOCK Pump_Control_VFD EXTENDS Pump_Control IMPLEMENTS IPumpVFD_ControlCommands
VAR_INPUT
END_VAR
VAR_OUTPUT
END_VAR
VAR
	ConditionStartVFD : BOOL;								// Переменная услвоия старта насоса от ЧРП
	ConditionSwitchToStart, ConditionSwitchToVFD : BOOL;	// Условия перехода насоса на ЧРП и обычный старт
END_VAR

METHOD Start_VFD
    VAR_INPUT
        access : BOOL;										// Доступ к функциональному блоку
        device : IPumpVFD_Control;							// Устройство управления насосом от ЧРП
    END_VAR

    IF access AND ConditionStartVFD THEN 
        device.Set_Power_VFD(TRUE);
    END_IF;
END_METHOD

METHOD Stop_VFD
    VAR_INPUT
        access: BOOL;										// Доступ к функциональному блоку
        device : IPumpVFD_Control;							// Устройство управления насосом от ЧРП
    END_VAR

    IF access AND ConditionStop THEN  
        device.Set_Power_VFD(FALSE);
    END_IF;
END_METHOD

METHOD SwitchToStart
    VAR_INPUT
        access : BOOL;										// Доступ к функциональному блоку
        device : IPumpVFD_Control;							// Устройство управления насосом от ЧРП
    END_VAR

    IF access AND ConditionSwitchToStart THEN 
        device.Set_Power_VFD(FALSE);
        device.Set_Power(TRUE);
    END_IF;
END_METHOD

METHOD SwitchToVFD
    VAR_INPUT
        access : BOOL;										// Доступ к функциональному блоку
        device : IPumpVFD_Control;							// Устройство управления насосом от ЧРП
    END_VAR

    IF access AND ConditionSwitchToVFD THEN 
        device.Set_Power(FALSE);
        device.Set_Power_VFD(TRUE);
    END_IF;
END_METHOD

PROPERTY AccessToStartVFD : BOOL
    SET
        ConditionStartVFD := AccessToStartVFD;
    END_SET
END_PROPERTY

PROPERTY AccessToSwitchToStart : BOOL
    SET
        ConditionSwitchToStart := AccessToSwitchToStart;
    END_SET
END_PROPERTY

PROPERTY AccessToSwitchToVFD : BOOL
    SET
        ConditionSwitchToVFD := AccessToSwitchToVFD;
    END_SET
END_PROPERTY
END_FUNCTION_BLOCK