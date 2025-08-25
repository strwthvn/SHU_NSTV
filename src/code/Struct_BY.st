TYPE Struct_BY :
STRUCT
	// Команды
	//xOpen, xClose, xStop, xReset : BOOL;
	Auto_xOpen, Auto_xClose, Auto_xStop, Auto_xReset : BOOL;
	Service_xOpen, Service_xClose, Service_xStop, Service_xReset : BOOL;
	ConditionToxOpen, ConditionToxClose, ConditionToxStop, ConditionToxAutoStop, ConditionToxReset : BOOL;
	sOpen, sClose, sStop, sReset : FB_SignalSplit;
	rtrig_xOpen, rtrig_xClose, rtrig_xStop, rtrig_xReset : R_TRIG;
	autoCmdWord : Union_ByteToWord;
	// Статусы
	xStatusOpen, xStatusClosed, xStatusStopped, xStatusError, xStatusReady, xStatusKmOpen, xStatusKmClose : BOOL;
	xOpenProcess, xCloseProcess : BOOL;
	StatusShutter : INT;
	StatusMotor : INT;
	StatusRemote : INT; // 0 - Выключен, 1 - Местный, 2 - Авто
	wStatus : Union_ByteToWord;
	// Обработка ошибок 
	ErrorOpen, ErrorClose, ErrorStop : FB_Error_SignalLongExpectation;
	xErrorLongExpectationOpen, xErrorLongExpectationClose, xErrorLongExpectationStop : BOOL;
	// Класс ЗРА
	Device : Shutter;
END_STRUCT
END_TYPE
