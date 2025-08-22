FUNCTION_BLOCK Pump_VFD EXTENDS PumpBasic IMPLEMENTS IPumpVFD_Control
VAR_INPUT
END_VAR
VAR_OUTPUT
END_VAR
VAR
	qxPowerVFD : BOOL;			// Выходной сигнал: 	Питание от ЧРП
END_VAR

METHOD Set_Power_VFD
    VAR_INPUT
        x : BOOL;				// Входной сигнал: 	Питание от ЧРП
    END_VAR
    qxPowerVFD := x;			// Присваиваем значение входного сигнала питания к выходному сигналу
END_METHOD
PROPERTY PowerVFD : BOOL 
    GET
        PowerVFD := qxPowerVFD;	// Возвращаем значение выходного сигнала питания от ЧРП
    END_GET
END_PROPERTY
