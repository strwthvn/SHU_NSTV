FUNCTION_BLOCK Control_VFD IMPLEMENTS BasicControlCommands
VAR_INPUT
END_VAR
VAR_OUTPUT
END_VAR
VAR
	conditionStart : BOOL;
	conditionStop : BOOL;
END_VAR

METHOD ResetFrequency
    VAR_INPUT
        access : BOOL;
        device : FrequencyCalculate;
    END_VAR
    IF access THEN device.Set_Frequency_Manual(0); END_IF;
END_METHOD

METHOD Start
    VAR_INPUT
        access : BOOL;					// Доступ к функциональному блоку
        device : BasicControl;			// Устройство управления частотным преобразователем
    END_VAR
    IF access AND conditionStart THEN
        device.Set_Power(TRUE);         // Включаем питание частотного преобразователя
    END_IF
END_METHOD

METHOD Stop
    VAR_INPUT
        access : BOOL;					// Доступ к функциональному блоку
        device : BasicControl;			// Устройство управления частотным преобразователем
    END_VAR
    IF access AND conditionStop THEN
        device.Set_Power(FALSE);        // Выключаем питание частотного преобразователя
    END_IF
END_METHOD

METHOD SwitchPower
    VAR_INPUT
        access : BOOL;
        device1 : BasicControl;	// Объект для выключения
        device2 : BasicControl;	// Объект для включения
    END_VAR
    IF access THEN
        device1.Set_Power(FALSE);	// Выключаем устройство
        device2.Set_Power(TRUE);	// Включаем устройство
    END_IF;
END_METHOD

PROPERTY AccessToStart : BOOL
    SET
        conditionStart := AccessToStart;	// Устанавливаем условие старта
    END_SET
END_PROPERTY

PROPERTY AccessToStop : BOOL
    SET
        conditionStop := AccessToStop;	// Устанавливаем условие остановки
    END_SET
END_PROPERTY