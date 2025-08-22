FUNCTION_BLOCK Basic_VFD IMPLEMENTS BasicControl, FrequencyCalculate
VAR_INPUT
END_VAR
VAR_OUTPUT
END_VAR
VAR
	// Конфигурация
	rMaxFreq : REAL;					// Максимальное задание частоты
	// Команды
	rSetFreq : REAL;					// Задание частоты
	// Условия
	ConditionToCalculate : BOOL;		// Условия для вычисления частоты
	// Выходные сигналы
	qxPower : BOOL;						// Питание
	qrFreq : REAL;						// Выходной сигнал частоты
	qScaledValue : UINT;				// Выходной сигнал для модуля
END_VAR

METHOD Calculate_Frequency	// Вычисление выходной частоты
    VAR_INPUT
        rStep : REAL;			// Шаг обновления частоты
        xProceed : BOOL;		// Импульс сигнал для вычисления в условиях цикла
    END_VAR
    IF xProceed AND ConditionToCalculate AND NOT (rMaxFreq < rSetFreq) THEN
        IF rSetFreq + rStep < qrFreq THEN
            qrFreq := qrFreq - rStep;
        ELSIF rSetFreq - rStep > qrFreq THEN
            qrFreq := qrFreq + rStep;
        ELSE
            qrFreq := rSetFreq;
        END_IF;
    END_IF;
END_METHOD

METHOD ConvertationToAsignal_0_1000 : UINT
    VAR
        TempValue : REAL;
    END_VAR
    TempValue := (qrFreq / rMaxFreq) * 1000.0;

    IF TempValue < 0.0 THEN
        ConvertationToAsignal_0_1000 := 0;
    ELSIF TempValue > 1000.0 THEN
        ConvertationToAsignal_0_1000 := 1000;
    ELSE
        ConvertationToAsignal_0_1000 := REAL_TO_UINT(TempValue);
    END_IF;
END_METHOD

METHOD Set_Frequency
    qrFreq := rSetFreq;
END_METHOD

METHOD Set_Frequency_Manual // Мгновенное задание частоты по требуемой
    VAR_INPUT
        rFrequency : REAL;
    END_VAR
    qrFreq := rFrequency;
END_METHOD

METHOD Set_Power
    VAR_INPUT
        x	: BOOL;
    END_VAR
    qxPower := x;
END_METHOD

PROPERTY AcessToCalculate : BOOL
    SET
        ConditionToCalculate := AcessToCalculate;
    END_SET
END_PROPERTY

PROPERTY Frequency : REAL
    GET
        Frequency := qrFreq;
    END_GET
    SET
        IF Frequency > rMaxFreq THEN
            rSetFreq := rMaxFreq;
        ELSIF Frequency < 0 THEN
            rSetFreq := 0;
        ELSE
            rSetFreq := Frequency;
        END_IF;
    END_SET
END_PROPERTY

PROPERTY FrequencyMax : REAL
    SET
        rMaxFreq := FrequencyMax;
    END_SET
END_PROPERTY

PROPERTY Power : BOOL
    GET
        Power := qxPower;	// Возвращаем значение выходного сигнала питания
    END_GET
END_PROPERTY
END_FUNCTION_BLOCK