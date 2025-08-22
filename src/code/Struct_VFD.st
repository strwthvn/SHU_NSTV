TYPE Struct_VFD :
STRUCT
	// Команды
	//xStart, xStop, xEmergencyStop, xReset, xSetToMain, xSetToReserve : BOOL;
	Auto_Start, Auto_Stop, Auto_EmergencyStop, Auto_Reset, Auto_SetToMain, Auto_SetToReserve : BOOL;
	Service_Start, Service_Stop, Service_EmergencyStop, Service_Reset, Service_SetToMain, Service_SetToReserve : BOOL;
	ConditionStart, ConditionStop, ConditionEmergencyStop, ConditionReset, ConditionSetToMain, ConditionSetToReserve, ConditionAutoStop : BOOL;
	rtrig_xStart, rtrig_xStop, rtrig_xEmergencyStop, rtrig_xReset, rtrig_xSetToMain, rtrig_xSetToReserve : R_TRIG;
	// Статусы
	xPower, xFailure, xWork, xManual, xReady 	: BOOL;
	xVariableWork : BOOL; // Для проверки совпадения с переменной фактической работы
	irFrequency : REAL; // Значение частоты в Гц от модуля аналогового входа
	qrFrequency : REAL; // Значение частоты в Гц от класса
	qiScaledFrequency_0_1000 : UINT; // Значение частоты от 0 до 1000 для задачи в модуль аналогового выхода
	
	// --- Передача состояний по птороколу Modbus ---
	// Аналоговый выход
	wStatusOutFrequency 		: Union_RealToWord; // Выходная частота 
	wStatusOutFrequencyState 	: Union_ByteToWord; // Слово состояние
	// ЧРП
	wStatusSetFrequency : Union_RealToWord; // Заданная команда
	wStatusStateCmd		: Union_ByteToWord; // Заданная команда
	wStatusState		: Union_ByteToWord; // Слово состояния
	wStatusStateError1	: Union_ByteToWord; // Слово неисправности
	wStatusUpFreqLimit	: Union_RealToWord; // Верхний предел частоты
	wStatusStateError2	: Union_ByteToWord; // Слово неисправности 2
	wStatusTorque 		: Union_RealToWord; // Значение крутящего момнета
	wStatusAO			: Union_RealToWord; // Значение АО
	// Класс ЧРП
	Device : Basic_VFD;	// Класс: базовый
END_STRUCT
END_TYPE
