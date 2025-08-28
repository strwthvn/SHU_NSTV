TYPE Struct_PU :
STRUCT
	// --- Команды ---
	Auto_xStartBP, Auto_xStartVFD, Auto_xStop, Auto_xSwitchToBP, Auto_xSwitchToVFD, Auto_xReset, Auto_xEmergencyStop : BOOL;
	Auto_xEnableLocalRemote : BOOL; // Разрешение на местное управление насосом
	Auto_xRequestLocalRemote : BOOL; // Запрос на местное управление
	
	Auto_cmdWord : Union_ByteToWord;
	Auto_cmdSetFreqWord : Union_RealToWord;

	Service_SetFrequency : REAL; // Задание частоты в режиме ПЛК СЕРВИС
	
	Service_xStartBP, Service_xStartVFD, Service_xStop, Service_xSwitchToBP, Service_xSwitchToVFD, Service_xReset, Service_xEmergencyStop : BOOL;
	xConditionToStartBP, xConditionToStartVFD, xConditionToSwitchToBP, xConditionToSwitchToVFD, xConditionToStop, xConditionToAutoStop : BOOL; // Условия выполнения команд
	
	ton_SwitchToBP, ton_SwitchToVFD : TON;
	xProcessSwitchToBP, xProcessSwitchToVFD : BOOL;

	rtrig_xStartBP        : R_TRIG;
	rtrig_xStartVFD       : R_TRIG;
	rtrig_xStop           : R_TRIG;
	rtrig_xSwitchToBP     : R_TRIG;
	rtrig_xSwitchToVFD    : R_TRIG;
	rtrig_xReset          : R_TRIG;
	rtrig_xEmergencyStop  : R_TRIG;
	
	ErrorxStartBP         : FB_Error_SignalLongExpectation;
	ErrorxStartVFD        : FB_Error_SignalLongExpectation;
	ErrorxStop            : FB_Error_SignalLongExpectation;
	ErrorxSwitchToBP      : FB_Error_SignalLongExpectation;
	ErrorxSwitchToVFD     : FB_Error_SignalLongExpectation;
	
	// --- Состояния ---
	// Дискретные входы
	xStatusEnableBP       : BOOL;
	xStatusEnableVFD      : BOOL;
	xStatusManual         : BOOL;
	xManualStart          : BOOL;
	xManualStop           : BOOL;
	xStatusDry            : BOOL;
	// Генерируемые состояния
	xCommonError          : BOOL;
	xEmergencyStopStatus  : BOOL;
	xWorkingFromVFD	  	: BOOL;
	
	xErrorLongTimeException_xStartBP     : BOOL;
	xErrorLongTimeException_xStartVFD    : BOOL;
	xErrorLongTimeException_xStop        : BOOL;
	xErrorLongTimeException_xSwitchToBP  : BOOL;
	xErrorLongTimeException_xSwitchToVFD : BOOL;
	
	xErrorLostFeedbackSignal  : BOOL;
	xErrorEnableStatusVFD : BOOL;
	
	xReadyToStartBP       : BOOL;
	xReadyToStartVFD      : BOOL;
	
	iStatus               	: INT;
	wStatus					: Union_ByteToWord;
	wCurrentSpeed			: Union_RealToWord;
	
	ton_ErrorLostFeedbackSignal : TON;
	
	// --- Класс насоса ---
	Device : Pump_VFD;
	
	// --- Предпусковая сигнализация ---
	cmdStartBP_StartSound      	: FB_StartSiren;
	cmdStartVFD_StartSound		: FB_StartSiren;
	xSoundSirenSetSound  : BOOL;
END_STRUCT

END_TYPE
