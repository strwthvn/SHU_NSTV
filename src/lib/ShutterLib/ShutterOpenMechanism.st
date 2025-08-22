FUNCTION_BLOCK ShutterOpenMechanism IMPLEMENTS BasicControl
VAR_INPUT
END_VAR
VAR_OUTPUT
END_VAR
VAR
	qxPower : BOOL;
END_VAR

METHOD Set_Power
    VAR_INPUT
        x : BOOL;				// Вход сигнала питания
    END_VAR
    qxPower := x;				// Присваиваем значение входного сигнала питания к выходному сигналу
END_METHOD

PROPERTY Power : BOOL 
    GET
        Power := qxPower;	// Возвращаем значение выходного сигнала питания
    END_GET
END_PROPERTY
END_FUNCTION_BLOCK