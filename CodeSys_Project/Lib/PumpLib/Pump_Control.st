FUNCTION_BLOCK Pump_Control IMPLEMENTS BasicControlCommands
VAR_INPUT
END_VAR
VAR_OUTPUT
END_VAR
VAR
	ConditionStart : BOOL;						// Условие на запуск
	ConditionStop : BOOL; 						// Условие на стоп.
END_VAR

METHOD Start
    VAR_INPUT
        access : BOOL;							// Доступ к запуску
        device : BasicControl;				        // Устройство управления насосом
    END_VAR

    IF access AND ConditionStart THEN
        device.Set_Power(TRUE);					// Запускаем насос
    END_IF;
END_METHOD

METHOD Stop
    VAR_INPUT
        access: BOOL;							// Доступ к остановке
        device : BasicControl;				        // Устройство управления насосом
    END_VAR

    IF access AND ConditionStop THEN
        device.Set_Power(FALSE);				// Останавливаем насос
    END_IF;
END_METHOD

PROPERTY AccessToStart : BOOL
    SET
        ConditionStart := AccessToStart;
    END_GET
END_PROPERTY

PROPERTY AccessToStop : BOOL
    SET
        ConditionStop := AccessToStop;
    END_GET
END_PROPERTY
