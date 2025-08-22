FUNCTION_BLOCK Shutter_Control
VAR_INPUT
END_VAR
VAR_OUTPUT
END_VAR
VAR
	ConditionOpen, ConditionClose, ConditionStop : BOOL;
END_VAR

METHOD Close
    VAR_INPUT
        access : BOOL;					// Доступ к функциональному блоку
        device : BasicControl_OpenClose;	// Устройство управления закрытием шторки
    END_VAR
    IF access AND ConditionClose THEN
        device.Close();                // Вызываем метод закрытия затвора
    END_IF
END_METHOD

METHOD Open
    VAR_INPUT
        access : BOOL;					// Доступ к функциональному блоку
        device : BasicControl_OpenClose;	// Устройство управления открытием шторки
    END_VAR
    IF access AND ConditionOpen THEN
        device.Open();                 // Вызываем метод открытия затвора
    END_IF
END_METHOD

METHOD Stop
    VAR_INPUT
        access : BOOL;					// Доступ к функциональному блоку
        device : BasicControl_OpenClose;	// Устройство управления остановкой шторки
    END_VAR
    IF access AND ConditionStop THEN
        device.Stop();                 // Вызываем метод остановки затвора
    END_IF
END_METHOD

PROPERTY AccessToOpen : BOOL
    SET
        ConditionOpen := AccessToOpen;	// Устанавливаем условие открытия шторки
    END_SET
END_PROPERTY

PROPERTY AccessToClose : BOOL
    SET
        ConditionClose := AccessToClose;	// Устанавливаем условие закрытия шторки
    END_SET
END_PROPERTY

PROPERTY AccessToStop : BOOL
    SET
        ConditionStop := AccessToStop;	// Устанавливаем условие остановки шторки
    END_SET
END_PROPERTY
END_FUNCTION_BLOCK
