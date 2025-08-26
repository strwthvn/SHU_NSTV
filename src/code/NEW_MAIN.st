PROGRAM NEW_MAIN
VAR CONSTANT
	PU_AMOUNT : INT := 5;				// Количество насосов
	PU_TIME_TO_AUTO_STOP_ERROR_LOST_FEEDBACK : TIME := T#60S; // Время до авоматического сброса питания контактора при потере сигнала обратной связи питания 
	VFD_AMOUNT : INT := 2;				// Количество ЧРП
	BY_AMOUNT : INT := 8;				// Количество ЗРА
	RATTLING_DELAY : TIME := T#100MS; 	// Задержка получения сигнала входов (защита от дребезга)
	//VFD_CMD_DELAY : TIME := T#10S;				// Время задержки сигнала старт и стоп до его отключения и выхода ошибки долгого ожидания отклика механизма
	LONG_TIME_EXPECTATION_TIME : TIME := T#60S;		// Время до генерации ошибки получения сигнала обратной связи после подачи команды
	LIFEBIT_CONNECTION_TIME : TIME := T#5S;			// Время получения сигнала LifeBit от ПЛК АСУТП
	LOST_CONNECTION_EMERGENCY_STOP_TIME : TIME := T#5S; // Тайм-аут аварийной остановки станции после получения сигнала о потери связи с ПЛК АСУТП (константа времени)
	EMERGENCY_STOP_PU_DELAY_TIME : TIME := T#5S;	// Время задержки отключения насосов для работы аварийной остановки (последовательная остановка насосов)
END_VAR
VAR
	// --- Режимы и состояние связи ---
	PLC_Mode : BYTE := 0; // 0 – «Авто», 1 – «Обрыв связи», 2 – «Местный-Сервис»
	PLC_LifeBit : BOOL := TRUE; // TRUE вручную на время симуляции
	PLC_Connection_Ok : BOOL;
	PLC_Connection_Fault : BOOL;
	PLC_cmd : Struct_PLC_Commands;
	PLC_Word : Union_ByteToWord;
	PLC_cmdWord : Union_ByteToWord;
	PLC_cmdResetAll : BOOL;
    rtrig_PLC_cmdResetAll : R_TRIG;
	PLC_ResetConnectionError : BOOL;
	PLC_SimulationCommunication : BOOL := TRUE;
	
	// Конфигурация ЧРП
	VFD_MAX_FREQ : REAL := 50;						// Максимальная уставка частоты
	VFD_MIN_FREQ : REAL := 20;						// Минимальная уставка частоты
	VFD_CHANGE_BP_TO_VFD_FREQ : REAL := 40;			// Задание частоты для переключения с БП на ЧРП
	VFD_CYCLE_UPDATE : TIME := T#2S;				// Время обновления цикла плавного пуска/остановки в TIME
	VFD_CYCLE_STEP : REAL := 15;					// Шаг обновления частоты за 1 цикл
	VFD_FREQ_INACCURANCY : REAL := 0.2;				// Максимальная допустимая погрешность для ЧРП
	VFD_FREQ_ACCESS_SWITCH_TO_BP : REAL := 48.5;	// Значение допустимой частоты для возможности переключения насоса с ЧРП на БП
	
	// --- Предпусковая сигнализация ---
	xSoundSirenOption : BOOL := FALSE; // Опция работы предпусковой звуковой сигнализации
	tFirtSoundTime : TIME := T#3S;		// Время первого звукового сигнала
	tSecondSoundTime : TIME := T#3S;	// Время второго звукового сигнала
	tSoundPause : TIME := T#3S;		// Задержка между первым и вторым сигналом
	
	// --- Контроль LifeBit ---
	sr_PLC_LifeBit_Control : SR;
	ton_PLC_LifeBit_Control_Off : TON;
	ton_PLC_LifeBit_Control_On : TON;
	
	// --- Аварийные сигналы ---
	xcmdEmergencyStopCommon : BOOL;                 // Моментальная аварийная остановка насосной станции
	xEmergencyStopCommon : BOOL; 
	xEmergencyStopCommonLostConnectionTimeOut : BOOL; // Команда общей аварийной остановки (по таймауту связи)
	rtrig_xEmergencyStopCommon : R_TRIG;
	ton_LostConnectionEmergencyStopTimeOut : TON;   // Тайм-аут аварийной остановки станции (потеря связи с ПЛК АСУТП)
	
	// --- Насосы и управление ---
	PU : ARRAY [1..PU_AMOUNT] OF Struct_PU;
	PU_CTRL : Pump_Control_VFD;
    PU_i : INT;
	Auto_xPu_Reset : BOOL;      // Обобщённый ресет на каждый насос (ошибки)
	Service_xPu_Reset : BOOL;
	
	// --- Частотные преобразователи и управление ---
	VFD : ARRAY [1..VFD_AMOUNT] OF Struct_VFD;
	VFD_CTRL : Control_VFD;
	iVFD_Change : INT := 1;          // Текущий работающий ЧРП
	Auto_rSetFrequency : REAL;       // Задание частоты (авто)
	Service_rSetFrequency : REAL;    // Задание частоты (сервис)
	
	// --- ЗРА и управление ---
	Shutter : ARRAY[1..BY_AMOUNT] OF Struct_BY;
	Shutter_CTRL : Shutter_Control;
    Shutter_i : INT;
	BY_ModbusRef : ARRAY [1..BY_AMOUNT] OF Struct_BY_ModbusRef;
	
	// --- Импульсы и обновления ---
	blink_UpdateCycle : BLINK;       // Цикл с задачей импульса для плавного изменения частоты
	rtrig_UpdateCyclePulse : R_TRIG;
	
	// --- Процесс аварийной плавной остановки ---
	EmergencyStopLostConnection_iCurrentPU : INT := -1;   // -1 — ещё не начали, 0 — ЧРП, 1..PU_AMOUNT — насосы от БП
	EmergencyStopLostConnection_tDelay     : TON;         // Таймер задержки
	EmergencyStopLostConnection_xDelayRun  : BOOL := FALSE; // Признак ожидания задержки
	
	// Дребезг сигналов
        in_0303_05_1_ixSection1_OverheatAlarm          	: INPUT_OUTPUT;
        in_0303_05_1_ixSection1_OverheatWarning        	: INPUT_OUTPUT;
        in_0303_05_1_ixVFD_Failure                     	: INPUT_OUTPUT;
        in_0303_05_1_ixVFD_InWork                      	: INPUT_OUTPUT;
        in_0303_05_1_ixVFD_Manual                      	: INPUT_OUTPUT;
        in_0303_05_1_ixVFD_Ready                       	: INPUT_OUTPUT;
        in_0303_05_2_ixSection1_OverheatAlarm          	: INPUT_OUTPUT;
        in_0303_05_2_ixSection1_OverheatWarning        	: INPUT_OUTPUT;
        in_0303_05_2_ixVFD_Failure                     	: INPUT_OUTPUT;
        in_0303_05_2_ixVFD_InWork                      	: INPUT_OUTPUT;
        in_0303_05_2_ixVFD_Manual                      	: INPUT_OUTPUT;
        in_0303_05_2_ixVFD_Ready                       	: INPUT_OUTPUT;
        in_0303_05_1KM8_ixStatusOn                     	: INPUT_OUTPUT;
        in_0303_05_2KM8_ixStatusOn                     	: INPUT_OUTPUT;
        in_0303_05_BY01_ixKM_PosClosed                 	: INPUT_OUTPUT;
        in_0303_05_BY01_ixKM_PosOpen                   	: INPUT_OUTPUT;
        in_0303_05_BY01_ixShutter_PosClosed            	: INPUT_OUTPUT;
        in_0303_05_BY01_ixShutter_PosOpen              	: INPUT_OUTPUT;
        in_0303_05_BY01_ixShutter_StatusError          	: INPUT_OUTPUT;
        in_0303_05_BY01_ixShutter_StatusReady          	: INPUT_OUTPUT;
        in_0303_05_BY02_ixKM_PosClosed                 	: INPUT_OUTPUT;
        in_0303_05_BY02_ixKM_PosOpen                   	: INPUT_OUTPUT;
        in_0303_05_BY02_ixShutter_PosClosed            	: INPUT_OUTPUT;
        in_0303_05_BY02_ixShutter_PosOpen              	: INPUT_OUTPUT;
        in_0303_05_BY02_ixShutter_StatusError          	: INPUT_OUTPUT;
        in_0303_05_BY02_ixShutter_StatusReady          	: INPUT_OUTPUT;
        in_0303_05_BY03_ixKM_PosClosed                 	: INPUT_OUTPUT;
        in_0303_05_BY03_ixKM_PosOpen                   	: INPUT_OUTPUT;
        in_0303_05_BY03_ixShutter_PosClosed            	: INPUT_OUTPUT;
        in_0303_05_BY03_ixShutter_PosOpen              	: INPUT_OUTPUT;
        in_0303_05_BY03_ixShutter_StatusError          	: INPUT_OUTPUT;
        in_0303_05_BY03_ixShutter_StatusReady          	: INPUT_OUTPUT;
        in_0303_05_BY04_ixKM_PosClosed                 	: INPUT_OUTPUT;
        in_0303_05_BY04_ixKM_PosOpen                   	: INPUT_OUTPUT;
        in_0303_05_BY04_ixShutter_PosClosed            	: INPUT_OUTPUT;
        in_0303_05_BY04_ixShutter_PosOpen              	: INPUT_OUTPUT;
        in_0303_05_BY04_ixShutter_StatusError          	: INPUT_OUTPUT;
        in_0303_05_BY04_ixShutter_StatusReady          	: INPUT_OUTPUT;
        in_0303_05_BY05_ixKM_PosClosed                 	: INPUT_OUTPUT;
        in_0303_05_BY05_ixKM_PosOpen                   	: INPUT_OUTPUT;
        in_0303_05_BY05_ixShutter_PosClosed            	: INPUT_OUTPUT;
        in_0303_05_BY05_ixShutter_PosOpen              	: INPUT_OUTPUT;
        in_0303_05_BY05_ixShutter_StatusError          	: INPUT_OUTPUT;
        in_0303_05_BY05_ixShutter_StatusReady          	: INPUT_OUTPUT;
        in_0303_05_BY07_ixKM_PosClosed                 	: INPUT_OUTPUT;
        in_0303_05_BY07_ixKM_PosOpen                   	: INPUT_OUTPUT;
        in_0303_05_BY07_ixShutter_PosClosed            	: INPUT_OUTPUT;
        in_0303_05_BY07_ixShutter_PosOpen              	: INPUT_OUTPUT;
        in_0303_05_BY07_ixShutter_StatusError          	: INPUT_OUTPUT;
        in_0303_05_BY07_ixShutter_StatusReady          	: INPUT_OUTPUT;
        in_0303_05_BY08_ixKM_PosClosed                 	: INPUT_OUTPUT;
        in_0303_05_BY08_ixKM_PosOpen                   	: INPUT_OUTPUT;
        in_0303_05_BY08_ixShutter_PosClosed            	: INPUT_OUTPUT;
        in_0303_05_BY08_ixShutter_PosOpen              	: INPUT_OUTPUT;
        in_0303_05_BY08_ixShutter_StatusError          	: INPUT_OUTPUT;
        in_0303_05_BY08_ixShutter_StatusReady          	: INPUT_OUTPUT;
        in_0303_05_PU01_ixKM_StatusManualStart         	: INPUT_OUTPUT;
        in_0303_05_PU01_ixKM_StatusManualStop          	: INPUT_OUTPUT;
        in_0303_05_PU01_ixKM_StatusOn                  	: INPUT_OUTPUT;
        in_0303_05_PU01_ixKM_VFD_StatusOn              	: INPUT_OUTPUT;
        in_0303_05_PU01_ixStatusManual                 	: INPUT_OUTPUT;
        in_0303_05_PU02_ixKM_StatusManualStart         	: INPUT_OUTPUT;
        in_0303_05_PU02_ixKM_StatusManualStop          	: INPUT_OUTPUT;
        in_0303_05_PU02_ixKM_StatusOn                  	: INPUT_OUTPUT;
        in_0303_05_PU02_ixKM_VFD_StatusOn              	: INPUT_OUTPUT;
        in_0303_05_PU02_ixStatusManual                 	: INPUT_OUTPUT;
        in_0303_05_PU03_ixKM_StatusManualStart         	: INPUT_OUTPUT;
        in_0303_05_PU03_ixKM_StatusManualStop          	: INPUT_OUTPUT;
        in_0303_05_PU03_ixKM_StatusOn                  	: INPUT_OUTPUT;
        in_0303_05_PU03_ixKM_VFD_StatusOn              	: INPUT_OUTPUT;
        in_0303_05_PU03_ixStatusManual                 	: INPUT_OUTPUT;
        in_0303_05_PU04_ixKM_StatusManualStart         	: INPUT_OUTPUT;
        in_0303_05_PU04_ixKM_StatusManualStop          	: INPUT_OUTPUT;
        in_0303_05_PU04_ixKM_StatusOn                  	: INPUT_OUTPUT;
        in_0303_05_PU04_ixKM_VFD_StatusOn              	: INPUT_OUTPUT;
        in_0303_05_PU04_ixStatusManual                 	: INPUT_OUTPUT;
        in_0303_05_PU05_ixKM_StatusManualStart         	: INPUT_OUTPUT;
        in_0303_05_PU05_ixKM_StatusManualStop          	: INPUT_OUTPUT;
        in_0303_05_PU05_ixKM_StatusOn                  	: INPUT_OUTPUT;
        in_0303_05_PU05_ixKM_VFD_StatusOn              	: INPUT_OUTPUT;
        in_0303_05_PU05_ixStatusManual                 	: INPUT_OUTPUT;
        in_0303_05_PU01_qxDryRun                       	: INPUT_OUTPUT;
        in_0303_05_PU02_qxDryRun                       	: INPUT_OUTPUT;
        in_0303_05_PU03_qxDryRun                       	: INPUT_OUTPUT;
        in_0303_05_PU04_qxDryRun                       	: INPUT_OUTPUT;
        in_0303_05_PU05_qxDryRun                       	: INPUT_OUTPUT;
        in_PowerSupplyIsOk_1							: INPUT_OUTPUT;
        in_PowerSupplyIsOk_2							: INPUT_OUTPUT;
	
	// Удалить и перенести в модуль
	xPowerSupplyIsOk_1 : BOOL;
	xPowerSupplyIsOk_2 : BOOL;
END_VAR

blink_UpdateCycle(ENABLE:= TRUE, TIMELOW:= T#2S, TIMEHIGH:= T#1S, OUT=> );
rtrig_UpdateCyclePulse(CLK:= blink_UpdateCycle.OUT);

Init_RattlingKM();
Init_PLC();
Init_Pump();
Init_VFD();
Init_BY();

Commands_Pump();
Commands_VFD();
Commands_PLC();
Commands_BY();

// Контроль связи с ПЛК АСУТП
IF PLC_Mode <> 2 AND NOT PLC_SimulationCommunication THEN
    PLC_ConnectionControl();
END_IF;

// Аварийная остановка по таймауту связи
IF xEmergencyStopCommonLostConnectionTimeOut THEN
	LostConnectionStopProcess();
END_IF;

// Аварийная остановка по кнопке или по таймауту связи
IF xEmergencyStopCommon THEN
	EmergencyStopCommon();
END_IF

// Сброс всех ошибок
rtrig_PLC_cmdResetAll(CLK:= PLC_cmdResetAll);
IF rtrig_PLC_cmdResetAll.Q THEN
    ResetAllErrors();
END_IF;

//IF NOT in_PowerSupplyIsOk_1.qxSignal OR NOT in_PowerSupplyIsOk_1.qxSignal THEN xEmergencyStopCommon := TRUE; END_IF;

(* Дребезг сигналов *)
METHOD Init_RattlingKM
    in_0303_05_1_ixSection1_OverheatAlarm(
        ixSignal:= _0303_05_1_ixSection1_OverheatAlarm, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_1_ixSection1_OverheatWarning(
        ixSignal:= _0303_05_1_ixSection1_OverheatWarning, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_1_ixVFD_Failure(
        ixSignal:= _0303_05_1_ixVFD_Failure, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_1_ixVFD_InWork(
        ixSignal:= _0303_05_1_ixVFD_InWork, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_1_ixVFD_Manual(
        ixSignal:= _0303_05_1_ixVFD_Manual, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_1_ixVFD_Ready(
        ixSignal:= _0303_05_1_ixVFD_Ready, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_2_ixSection1_OverheatAlarm(
        ixSignal:= _0303_05_2_ixSection1_OverheatAlarm, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_2_ixSection1_OverheatWarning(
        ixSignal:= _0303_05_2_ixSection1_OverheatWarning, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_2_ixVFD_Failure(
        ixSignal:= _0303_05_2_ixVFD_Failure, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_2_ixVFD_InWork(
        ixSignal:= _0303_05_2_ixVFD_InWork, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_2_ixVFD_Manual(
        ixSignal:= _0303_05_2_ixVFD_Manual, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_2_ixVFD_Ready(
        ixSignal:= _0303_05_2_ixVFD_Ready, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_1KM8_ixStatusOn(
        ixSignal:= _0303_05_1KM8_ixStatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_2KM8_ixStatusOn(
        ixSignal:= _0303_05_2KM8_ixStatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY01_ixKM_PosClosed(
        ixSignal:= _0303_05_BY01_ixKM_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY01_ixKM_PosOpen(
        ixSignal:= _0303_05_BY01_ixKM_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY01_ixShutter_PosClosed(
        ixSignal:= _0303_05_BY01_ixShutter_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY01_ixShutter_PosOpen(
        ixSignal:= _0303_05_BY01_ixShutter_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY01_ixShutter_StatusError(
        ixSignal:= _0303_05_BY01_ixShutter_StatusError, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY01_ixShutter_StatusReady(
        ixSignal:= _0303_05_BY01_ixShutter_StatusReady, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY02_ixKM_PosClosed(
        ixSignal:= _0303_05_BY02_ixKM_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY02_ixKM_PosOpen(
        ixSignal:= _0303_05_BY02_ixKM_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY02_ixShutter_PosClosed(
        ixSignal:= _0303_05_BY02_ixShutter_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY02_ixShutter_PosOpen(
        ixSignal:= _0303_05_BY02_ixShutter_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY02_ixShutter_StatusError(
        ixSignal:= _0303_05_BY02_ixShutter_StatusError, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY02_ixShutter_StatusReady(
        ixSignal:= _0303_05_BY02_ixShutter_StatusReady, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY03_ixKM_PosClosed(
        ixSignal:= _0303_05_BY03_ixKM_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY03_ixKM_PosOpen(
        ixSignal:= _0303_05_BY03_ixKM_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY03_ixShutter_PosClosed(
        ixSignal:= _0303_05_BY03_ixShutter_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY03_ixShutter_PosOpen(
        ixSignal:= _0303_05_BY03_ixShutter_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY03_ixShutter_StatusError(
        ixSignal:= _0303_05_BY03_ixShutter_StatusError, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY03_ixShutter_StatusReady(
        ixSignal:= _0303_05_BY03_ixShutter_StatusReady, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY04_ixKM_PosClosed(
        ixSignal:= _0303_05_BY04_ixKM_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY04_ixKM_PosOpen(
        ixSignal:= _0303_05_BY04_ixKM_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY04_ixShutter_PosClosed(
        ixSignal:= _0303_05_BY04_ixShutter_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY04_ixShutter_PosOpen(
        ixSignal:= _0303_05_BY04_ixShutter_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY04_ixShutter_StatusError(
        ixSignal:= _0303_05_BY04_ixShutter_StatusError, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY04_ixShutter_StatusReady(
        ixSignal:= _0303_05_BY04_ixShutter_StatusReady, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY05_ixKM_PosClosed(
        ixSignal:= _0303_05_BY05_ixKM_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY05_ixKM_PosOpen(
        ixSignal:= _0303_05_BY05_ixKM_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY05_ixShutter_PosClosed(
        ixSignal:= _0303_05_BY05_ixShutter_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY05_ixShutter_PosOpen(
        ixSignal:= _0303_05_BY05_ixShutter_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY05_ixShutter_StatusError(
        ixSignal:= _0303_05_BY05_ixShutter_StatusError, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY05_ixShutter_StatusReady(
        ixSignal:= _0303_05_BY05_ixShutter_StatusReady, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY07_ixKM_PosClosed(
        ixSignal:= _0303_05_BY07_ixKM_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY07_ixKM_PosOpen(
        ixSignal:= _0303_05_BY07_ixKM_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY07_ixShutter_PosClosed(
        ixSignal:= _0303_05_BY07_ixShutter_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY07_ixShutter_PosOpen(
        ixSignal:= _0303_05_BY07_ixShutter_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY07_ixShutter_StatusError(
        ixSignal:= _0303_05_BY07_ixShutter_StatusError, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY07_ixShutter_StatusReady(
        ixSignal:= _0303_05_BY07_ixShutter_StatusReady, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY08_ixKM_PosClosed(
        ixSignal:= _0303_05_BY08_ixKM_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY08_ixKM_PosOpen(
        ixSignal:= _0303_05_BY08_ixKM_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY08_ixShutter_PosClosed(
        ixSignal:= _0303_05_BY08_ixShutter_PosClosed, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY08_ixShutter_PosOpen(
        ixSignal:= _0303_05_BY08_ixShutter_PosOpen, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY08_ixShutter_StatusError(
        ixSignal:= _0303_05_BY08_ixShutter_StatusError, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_BY08_ixShutter_StatusReady(
        ixSignal:= _0303_05_BY08_ixShutter_StatusReady, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU01_ixKM_StatusManualStart(
        ixSignal:= _0303_05_PU01_ixKM_StatusManualStart, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU01_ixKM_StatusManualStop(
        ixSignal:= _0303_05_PU01_ixKM_StatusManualStop, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU01_ixKM_StatusOn(
        ixSignal:= _0303_05_PU01_ixKM_StatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU01_ixKM_VFD_StatusOn(
        ixSignal:= _0303_05_PU01_ixKM_VFD_StatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU01_ixStatusManual(
        ixSignal:= _0303_05_PU01_ixStatusManual, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU02_ixKM_StatusManualStart(
        ixSignal:= _0303_05_PU02_ixKM_StatusManualStart, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU02_ixKM_StatusManualStop(
        ixSignal:= _0303_05_PU02_ixKM_StatusManualStop, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU02_ixKM_StatusOn(
        ixSignal:= _0303_05_PU02_ixKM_StatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU02_ixKM_VFD_StatusOn(
        ixSignal:= _0303_05_PU02_ixKM_VFD_StatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU02_ixStatusManual(
        ixSignal:= _0303_05_PU02_ixStatusManual, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU03_ixKM_StatusManualStart(
        ixSignal:= _0303_05_PU03_ixKM_StatusManualStart, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU03_ixKM_StatusManualStop(
        ixSignal:= _0303_05_PU03_ixKM_StatusManualStop, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU03_ixKM_StatusOn(
        ixSignal:= _0303_05_PU03_ixKM_StatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU03_ixKM_VFD_StatusOn(
        ixSignal:= _0303_05_PU03_ixKM_VFD_StatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU03_ixStatusManual(
        ixSignal:= _0303_05_PU03_ixStatusManual, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU04_ixKM_StatusManualStart(
        ixSignal:= _0303_05_PU04_ixKM_StatusManualStart, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU04_ixKM_StatusManualStop(
        ixSignal:= _0303_05_PU04_ixKM_StatusManualStop, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU04_ixKM_StatusOn(
        ixSignal:= _0303_05_PU04_ixKM_StatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU04_ixKM_VFD_StatusOn(
        ixSignal:= _0303_05_PU04_ixKM_VFD_StatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU04_ixStatusManual(
        ixSignal:= _0303_05_PU04_ixStatusManual, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU05_ixKM_StatusManualStart(
        ixSignal:= _0303_05_PU05_ixKM_StatusManualStart, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU05_ixKM_StatusManualStop(
        ixSignal:= _0303_05_PU05_ixKM_StatusManualStop,
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU05_ixKM_StatusOn(
        ixSignal:= _0303_05_PU05_ixKM_StatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU05_ixKM_VFD_StatusOn(
        ixSignal:= _0303_05_PU05_ixKM_VFD_StatusOn, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU05_ixStatusManual(
        ixSignal:= _0303_05_PU05_ixStatusManual, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU01_qxDryRun(
        ixSignal:= _0303_05_PU01_qxDryRun, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU02_qxDryRun(
        ixSignal:= _0303_05_PU02_qxDryRun, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU03_qxDryRun(
        ixSignal:= _0303_05_PU03_qxDryRun, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU04_qxDryRun(
        ixSignal:= _0303_05_PU04_qxDryRun, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_0303_05_PU05_qxDryRun(
        ixSignal:= _0303_05_PU05_qxDryRun, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
    in_PowerSupplyIsOk_1(
        ixSignal:= xPowerSupplyIsOk_1, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );
        
    in_PowerSupplyIsOk_2(
        ixSignal:= xPowerSupplyIsOk_2, 
        itInputTime:= RATTLING_DELAY, 
        itRattling_count_reset:= , 
        ixResetAlarm:= , 
        qxSignal=> , 
        qxRattlingAlarm=> );

(* Возвращает наличие работающего насоса от ЧРП *)
METHOD Get_PU_VFD_Common : BOOL
    VAR
        i : INT;
    END_VAR

    FOR i := 1 TO PU_AMOUNT DO
        IF PU[i].Device.PowerVFD THEN
            Get_PU_VFD_Common := TRUE;
            RETURN;
        END_IF;
    END_FOR;

    Get_PU_VFD_Common := FALSE;
END_METHOD

(* Возвращает номер работающего насоса от ЧРП *)
METHOD GET_PU_VFD_Number : INT
    VAR
        i : INT;
    END_VAR

    FOR i := 1 TO PU_AMOUNT DO
        IF PU[i].Device.PowerVFD THEN
            Get_PU_VFD_Number := i;
            RETURN;
        END_IF;
    END_FOR;

    Get_PU_VFD_Number := 0;
END_METHOD

METHOD Init_LongTimeExpectation
    VAR_INPUT
        refClass : REFERENCE TO FB_Error_SignalLongExpectation;  // Явная ссылка
        execute : BOOL;
        feedback : BOOL;
        error : REFERENCE TO BOOL;
    END_VAR
    VAR_OUTPUT
        error : BOOL;
    END_VAR

    IF __ISVALIDREF(refClass) THEN
        refClass.SetExecute(execute);
        refClass.SetFeedback(feedback);
        refClass.SetTimeout(LONG_TIME_EXPECTATION_TIME);
        error := refClass.GetError();
    END_IF
END_METHOD


(* Инициализация ЗРА *)
METHOD Init_BY
    VAR
        i : INT;
    END_VAR

    // --- Привязка сигналов от ЗРА по Modbus

    // --- BY01 ---
    BY_ModbusRef[1].RemoteMode       := BY01_F_RemoteMode;
    BY_ModbusRef[1].LocalMode        := BY01_F_LocalMode;
    BY_ModbusRef[1].OpenedPosition   := BY01_F_OpenedPosition;
    BY_ModbusRef[1].ClosedPosition   := BY01_F_ClosedPosition;
    BY_ModbusRef[1].SetPointReached  := BY01_F_SetPointReached;
    BY_ModbusRef[1].NotReadyInd      := BY01_F_NotReadyInd;
    BY_ModbusRef[1].RunningOpen      := BY01_F_RunningOpen;
    BY_ModbusRef[1].RunningClose     := BY01_F_RunningClose;
    BY_ModbusRef[1].ProhibitLocalAct := BY01_F_ProhibitLocalAction;
    BY_ModbusRef[1].FaultInd         := BY01_F_FaultInd;

    // --- BY02 ---
    BY_ModbusRef[2].RemoteMode       := BY02_F_RemoteMode;
    BY_ModbusRef[2].LocalMode        := BY02_F_LocalMode;
    BY_ModbusRef[2].OpenedPosition   := BY02_F_OpenedPosition;
    BY_ModbusRef[2].ClosedPosition   := BY02_F_ClosedPosition;
    BY_ModbusRef[2].SetPointReached  := BY02_F_SetPointReached;
    BY_ModbusRef[2].NotReadyInd      := BY02_F_NotReadyInd;
    BY_ModbusRef[2].RunningOpen      := BY02_F_RunningOpen;
    BY_ModbusRef[2].RunningClose     := BY02_F_RunningClose;
    BY_ModbusRef[2].ProhibitLocalAct := BY02_F_ProhibitLocalAction;
    BY_ModbusRef[2].FaultInd         := BY02_F_FaultInd;

    // --- BY03 ---
    BY_ModbusRef[3].RemoteMode       := BY03_F_RemoteMode;
    BY_ModbusRef[3].LocalMode        := BY03_F_LocalMode;
    BY_ModbusRef[3].OpenedPosition   := BY03_F_OpenedPosition;
    BY_ModbusRef[3].ClosedPosition   := BY03_F_ClosedPosition;
    BY_ModbusRef[3].SetPointReached  := BY03_F_SetPointReached;
    BY_ModbusRef[3].NotReadyInd      := BY03_F_NotReadyInd;
    BY_ModbusRef[3].RunningOpen      := BY03_F_RunningOpen;
    BY_ModbusRef[3].RunningClose     := BY03_F_RunningClose;
    BY_ModbusRef[3].ProhibitLocalAct := BY03_F_ProhibitLocalAction;
    BY_ModbusRef[3].FaultInd         := BY03_F_FaultInd;

    // --- BY04 ---
    BY_ModbusRef[4].RemoteMode       := BY04_F_RemoteMode;
    BY_ModbusRef[4].LocalMode        := BY04_F_LocalMode;
    BY_ModbusRef[4].OpenedPosition   := BY04_F_OpenedPosition;
    BY_ModbusRef[4].ClosedPosition   := BY04_F_ClosedPosition;
    BY_ModbusRef[4].SetPointReached  := BY04_F_SetPointReached;
    BY_ModbusRef[4].NotReadyInd      := BY04_F_NotReadyInd;
    BY_ModbusRef[4].RunningOpen      := BY04_F_RunningOpen;
    BY_ModbusRef[4].RunningClose     := BY04_F_RunningClose;
    BY_ModbusRef[4].ProhibitLocalAct := BY04_F_ProhibitLocalAction;
    BY_ModbusRef[4].FaultInd         := BY04_F_FaultInd;

    // --- BY05 ---
    BY_ModbusRef[5].RemoteMode       := BY05_F_RemoteMode;
    BY_ModbusRef[5].LocalMode        := BY05_F_LocalMode;
    BY_ModbusRef[5].OpenedPosition   := BY05_F_OpenedPosition;
    BY_ModbusRef[5].ClosedPosition   := BY05_F_ClosedPosition;
    BY_ModbusRef[5].SetPointReached  := BY05_F_SetPointReached;
    BY_ModbusRef[5].NotReadyInd      := BY05_F_NotReadyInd;
    BY_ModbusRef[5].RunningOpen      := BY05_F_RunningOpen;
    BY_ModbusRef[5].RunningClose     := BY05_F_RunningClose;
    BY_ModbusRef[5].ProhibitLocalAct := BY05_F_ProhibitLocalAction;
    BY_ModbusRef[5].FaultInd         := BY05_F_FaultInd;

    // --- BY07 ---
    BY_ModbusRef[7].RemoteMode       := BY07_F_RemoteMode;
    BY_ModbusRef[7].LocalMode        := BY07_F_LocalMode;
    BY_ModbusRef[7].OpenedPosition   := BY07_F_OpenedPosition;
    BY_ModbusRef[7].ClosedPosition   := BY07_F_ClosedPosition;
    BY_ModbusRef[7].SetPointReached  := BY07_F_SetPointReached;
    BY_ModbusRef[7].NotReadyInd      := BY07_F_NotReadyInd;
    BY_ModbusRef[7].RunningOpen      := BY07_F_RunningOpen;
    BY_ModbusRef[7].RunningClose     := BY07_F_RunningClose;
    BY_ModbusRef[7].ProhibitLocalAct := BY07_F_ProhibitLocalAction;
    BY_ModbusRef[7].FaultInd         := BY07_F_FaultInd;

    // --- BY08 ---
    BY_ModbusRef[8].RemoteMode       := BY08_F_RemoteMode;
    BY_ModbusRef[8].LocalMode        := BY08_F_LocalMode;
    BY_ModbusRef[8].OpenedPosition   := BY08_F_OpenedPosition;
    BY_ModbusRef[8].ClosedPosition   := BY08_F_ClosedPosition;
    BY_ModbusRef[8].SetPointReached  := BY08_F_SetPointReached;
    BY_ModbusRef[8].NotReadyInd      := BY08_F_NotReadyInd;
    BY_ModbusRef[8].RunningOpen      := BY08_F_RunningOpen;
    BY_ModbusRef[8].RunningClose     := BY08_F_RunningClose;
    BY_ModbusRef[8].ProhibitLocalAct := BY08_F_ProhibitLocalAction;
    BY_ModbusRef[8].FaultInd         := BY08_F_FaultInd;


    Shutter[1].xStatusClosed := in_0303_05_BY01_ixShutter_PosClosed.qxSignal;
    Shutter[1].xStatusOpen := in_0303_05_BY01_ixShutter_PosOpen.qxSignal;
    Shutter[1].xStatusError := in_0303_05_BY01_ixShutter_StatusError.qxSignal;
    Shutter[1].xStatusReady := in_0303_05_BY01_ixShutter_StatusReady.qxSignal;
    Shutter[1].xStatusKmOpen := in_0303_05_BY01_ixKM_PosOpen.qxSignal;
    Shutter[1].xStatusKmClose := in_0303_05_BY01_ixKM_PosClosed.qxSignal;

    Shutter[2].xStatusClosed := in_0303_05_BY02_ixShutter_PosClosed.qxSignal;
    Shutter[2].xStatusOpen   := in_0303_05_BY02_ixShutter_PosOpen.qxSignal;
    Shutter[2].xStatusError  := in_0303_05_BY02_ixShutter_StatusError.qxSignal;
    Shutter[2].xStatusReady  := in_0303_05_BY02_ixShutter_StatusReady.qxSignal;
    Shutter[2].xStatusKmOpen := in_0303_05_BY02_ixKM_PosOpen.qxSignal;
    Shutter[2].xStatusKmClose := in_0303_05_BY02_ixKM_PosClosed.qxSignal;

    Shutter[3].xStatusClosed := in_0303_05_BY03_ixShutter_PosClosed.qxSignal;
    Shutter[3].xStatusOpen   := in_0303_05_BY03_ixShutter_PosOpen.qxSignal;
    Shutter[3].xStatusError  := in_0303_05_BY03_ixShutter_StatusError.qxSignal;
    Shutter[3].xStatusReady  := in_0303_05_BY03_ixShutter_StatusReady.qxSignal;
    Shutter[3].xStatusKmOpen := in_0303_05_BY03_ixKM_PosOpen.qxSignal;
    Shutter[3].xStatusKmClose := in_0303_05_BY03_ixKM_PosClosed.qxSignal;

    Shutter[4].xStatusClosed := in_0303_05_BY04_ixShutter_PosClosed.qxSignal;
    Shutter[4].xStatusOpen   := in_0303_05_BY04_ixShutter_PosOpen.qxSignal;
    Shutter[4].xStatusError  := in_0303_05_BY04_ixShutter_StatusError.qxSignal;
    Shutter[4].xStatusReady  := in_0303_05_BY04_ixShutter_StatusReady.qxSignal;
    Shutter[4].xStatusKmOpen := in_0303_05_BY04_ixKM_PosOpen.qxSignal;
    Shutter[4].xStatusKmClose := in_0303_05_BY04_ixKM_PosClosed.qxSignal;

    Shutter[5].xStatusClosed := in_0303_05_BY05_ixShutter_PosClosed.qxSignal;
    Shutter[5].xStatusOpen   := in_0303_05_BY05_ixShutter_PosOpen.qxSignal;
    Shutter[5].xStatusError  := in_0303_05_BY05_ixShutter_StatusError.qxSignal;
    Shutter[5].xStatusReady  := in_0303_05_BY05_ixShutter_StatusReady.qxSignal;
    Shutter[5].xStatusKmOpen := in_0303_05_BY05_ixKM_PosOpen.qxSignal;
    Shutter[5].xStatusKmClose := in_0303_05_BY05_ixKM_PosClosed.qxSignal;

    Shutter[7].xStatusClosed := in_0303_05_BY07_ixShutter_PosClosed.qxSignal;
    Shutter[7].xStatusOpen   := in_0303_05_BY07_ixShutter_PosOpen.qxSignal;
    Shutter[7].xStatusError  := in_0303_05_BY07_ixShutter_StatusError.qxSignal;
    Shutter[7].xStatusReady  := in_0303_05_BY07_ixShutter_StatusReady.qxSignal;
    Shutter[7].xStatusKmOpen := in_0303_05_BY07_ixKM_PosOpen.qxSignal;
    Shutter[7].xStatusKmClose := in_0303_05_BY07_ixKM_PosClosed.qxSignal;

    Shutter[8].xStatusClosed := in_0303_05_BY08_ixShutter_PosClosed.qxSignal;
    Shutter[8].xStatusOpen   := in_0303_05_BY08_ixShutter_PosOpen.qxSignal;
    Shutter[8].xStatusError  := in_0303_05_BY08_ixShutter_StatusError.qxSignal;
    Shutter[8].xStatusReady  := in_0303_05_BY08_ixShutter_StatusReady.qxSignal;
    Shutter[8].xStatusKmOpen := in_0303_05_BY08_ixKM_PosOpen.qxSignal;
    Shutter[8].xStatusKmClose := in_0303_05_BY08_ixKM_PosClosed.qxSignal;

    FOR i := 1 TO BY_AMOUNT BY 1 DO
       	
        Shutter[i].ErrorOpen();
        Shutter[i].ErrorClose();
        Shutter[i].ErrorStop();
        
        Shutter[i].ErrorOpen.Initialize(Shutter[i].rtrig_xOpen.Q, Shutter[i].xStatusKmOpen, shutter[i].xErrorLongExpectationOpen, LONG_TIME_EXPECTATION_TIME);
        Shutter[i].ErrorClose.Initialize(Shutter[i].rtrig_xClose.Q, Shutter[i].xStatusKmClose, shutter[i].xErrorLongExpectationClose, LONG_TIME_EXPECTATION_TIME);
        Shutter[i].ErrorStop.Initialize(Shutter[i].rtrig_xStop.Q, NOT Shutter[i].xStatusKmClose AND NOT Shutter[i].xStatusKmOpen, shutter[i].xErrorLongExpectationStop, LONG_TIME_EXPECTATION_TIME);
        
        // --- Передача состояния по протоколу Modbus ---
        Shutter[i].wStatus.VarByte[0].0 := Shutter[i].xStatusOpen;
        Shutter[i].wStatus.VarByte[0].1 := Shutter[i].xStatusClosed;
        Shutter[i].wStatus.VarByte[0].2 := Shutter[i].xStatusKmOpen;
        Shutter[i].wStatus.VarByte[0].3 := Shutter[i].xStatusKmClose;
        Shutter[i].wStatus.VarByte[0].4 := Shutter[i].xStatusOpen;
        Shutter[i].wStatus.VarByte[0].5 := Shutter[i].xStatusOpen;
        Shutter[i].wStatus.VarByte[0].5 := BY_ModbusRef[i].RemoteMode;
        Shutter[i].wStatus.VarByte[0].6 := BY_ModbusRef[i].LocalMode;
        Shutter[i].wStatus.VarByte[0].7 := BY_ModbusRef[i].OpenedPosition;
        Shutter[i].wStatus.VarByte[1].0 := BY_ModbusRef[i].ClosedPosition;
        Shutter[i].wStatus.VarByte[1].1 := BY_ModbusRef[i].SetPointReached;
        Shutter[i].wStatus.VarByte[1].2 := BY_ModbusRef[i].NotReadyInd;
        Shutter[i].wStatus.VarByte[1].3 := BY_ModbusRef[i].RunningOpen;
        Shutter[i].wStatus.VarByte[1].4 := BY_ModbusRef[i].RunningClose;
        Shutter[i].wStatus.VarByte[1].5 := BY_ModbusRef[i].ProhibitLocalAct;
        Shutter[i].wStatus.VarByte[1].6 := BY_ModbusRef[i].FaultInd;
        
        // --- Получение команд по протоколу Modbus ---
        Shutter[i].Auto_xOpen 		:= 	Shutter[i].autoCmdWord.VarByte[0].0;
        Shutter[i].Auto_xClose 		:= 	Shutter[i].autoCmdWord.VarByte[0].1;
        Shutter[i].Auto_xStop 		:= 	Shutter[i].autoCmdWord.VarByte[0].2;
        Shutter[i].Auto_xReset 		:= 	Shutter[i].autoCmdWord.VarByte[0].3;
    END_FOR;
END_METHOD
(* Инициализация ПЛК *)
METHOD Init_PLC
    // Передача состояния по протоколу Modbus 
    PLC_Word.VarByte[0].0 := PLC_LifeBit;
    PLC_Word.VarByte[0].1 := PLC_Connection_Ok;
    //PLC_Word.VarByte[0].2 := PLC_Err;
    //PLC_Word.VarByte[0].2 := AlarmMeh;
    PLC_Word.VarByte[0].2 := PLC_Connection_Fault;
    PLC_Word.VarByte[1] := PLC_Mode;

    // Получение команд по протоколу Modbus
    PLC_LifeBit := PLC_cmdWord.VarByte[0].0;
    PLC_cmdResetAll := PLC_cmdWord.VarByte[0].1;
    PLC_ResetConnectionError := PLC_cmdWord.VarByte[0].2;
END_METHOD
(* Инициализация насосов *)
METHOD Init_Pump
    VAR
        i : INT;
    END_VAR

    // PU 1
    PU[1].xStatusEnableBP := in_0303_05_PU01_ixKM_StatusOn.qxSignal;
    PU[1].xStatusEnableVFD := in_0303_05_PU01_ixKM_VFD_StatusOn.qxSignal;
    PU[1].xManualStart := in_0303_05_PU01_ixKM_StatusManualStart.qxSignal;
    PU[1].xManualStop := in_0303_05_PU01_ixKM_StatusManualStop.qxSignal;
    PU[1].xStatusManual := in_0303_05_PU01_ixStatusManual.qxSignal;
    PU[1].xStatusDry := in_0303_05_PU01_qxDryRun.qxSignal;
    // PU 2
    PU[2].xStatusEnableBP := in_0303_05_PU02_ixKM_StatusOn.qxSignal;
    PU[2].xStatusEnableVFD := in_0303_05_PU02_ixKM_VFD_StatusOn.qxSignal;
    PU[2].xManualStart := in_0303_05_PU02_ixKM_StatusManualStart.qxSignal;
    PU[2].xManualStop := in_0303_05_PU02_ixKM_StatusManualStop.qxSignal;
    PU[2].xStatusManual := in_0303_05_PU02_ixStatusManual.qxSignal;
    PU[2].xStatusDry := in_0303_05_PU02_qxDryRun.qxSignal;
    // PU 3
    PU[3].xStatusEnableBP := in_0303_05_PU03_ixKM_StatusOn.qxSignal;
    PU[3].xStatusEnableVFD := in_0303_05_PU03_ixKM_VFD_StatusOn.qxSignal;
    PU[3].xManualStart := in_0303_05_PU03_ixKM_StatusManualStart.qxSignal;
    PU[3].xManualStop := in_0303_05_PU03_ixKM_StatusManualStop.qxSignal;
    PU[3].xStatusManual := in_0303_05_PU03_ixStatusManual.qxSignal;
    PU[3].xStatusDry := in_0303_05_PU03_qxDryRun.qxSignal;
    // PU 4
    PU[4].xStatusEnableBP := in_0303_05_PU04_ixKM_StatusOn.qxSignal;
    PU[4].xStatusEnableVFD := in_0303_05_PU04_ixKM_VFD_StatusOn.qxSignal;
    PU[4].xManualStart := in_0303_05_PU04_ixKM_StatusManualStart.qxSignal;
    PU[4].xManualStop := in_0303_05_PU04_ixKM_StatusManualStop.qxSignal;
    PU[4].xStatusManual := in_0303_05_PU04_ixStatusManual.qxSignal;
    PU[4].xStatusDry := in_0303_05_PU04_qxDryRun.qxSignal;
    // PU 5
    PU[5].xStatusEnableBP := in_0303_05_PU05_ixKM_StatusOn.qxSignal;
    PU[5].xStatusEnableVFD := in_0303_05_PU05_ixKM_VFD_StatusOn.qxSignal;
    PU[5].xManualStart := in_0303_05_PU05_ixKM_StatusManualStart.qxSignal;
    PU[5].xManualStop := in_0303_05_PU05_ixKM_StatusManualStop.qxSignal;
    PU[5].xStatusManual := in_0303_05_PU05_ixStatusManual.qxSignal;
    PU[5].xStatusDry := in_0303_05_PU05_qxDryRun.qxSignal;
    // Задание частоты индивидуально на каждый насос
    Auto_rSetFrequency := PU[Get_PU_VFD_Number()].Auto_cmdSetFreqWord.rTag;

    FOR i := 1 TO PU_AMOUNT BY 1 DO
        // Передача обобщённой RESET команды на каждый насос
        CASE PLC_Mode OF 0: PU[i].Auto_xReset := Auto_xPu_Reset; 2: PU[i].Service_xReset := Service_xPu_Reset; END_CASE;

        PU[i].ErrorxStartBP();
        PU[i].ErrorxStartVFD();
        PU[i].ErrorxSwitchToBP();
        PU[i].ErrorxSwitchToVFD();
        PU[i].ErrorxStop();
        
        PU[i].ErrorxStartBP.Initialize(PU[i].rtrig_xStartBP.Q AND PU[i].xConditionToStartBP, PU[i].xStatusEnableBP, PU[i].xErrorLongTimeException_xStartBP, LONG_TIME_EXPECTATION_TIME);
        // Обработка ошибки команды СТАРТ С ЧРП и получения обратной связи
        PU[i].ErrorxStartVFD.Initialize(PU[i].rtrig_xStartVFD.Q AND PU[i].xConditionToStartVFD, PU[i].xStatusEnableVFD, PU[i].xErrorLongTimeException_xStartVFD, LONG_TIME_EXPECTATION_TIME);
        // Обработка ошибки команды СТОП и получения обратной связи
        PU[i].ErrorxStop.Initialize(PU[i].rtrig_xStop.Q, NOT PU[i].xStatusEnableBP AND NOT PU[i].xStatusEnableVFD, PU[i].xErrorLongTimeException_xStop, LONG_TIME_EXPECTATION_TIME);
        // Обработка ошибки команды ПЕРЕКЛЮЧЕНИЕ НА БП и получения обратной связи
        PU[i].ErrorxSwitchToBP.Initialize(PU[i].rtrig_xSwitchToBP.Q AND PU[i].xConditionToSwitchToBP, PU[i].xStatusEnableBP AND NOT PU[i].xStatusEnableVFD, PU[i].xErrorLongTimeException_xSwitchToBP, LONG_TIME_EXPECTATION_TIME);
        // Обработка ошибки команды ПЕРЕКЛЮЧЕНИЕ НА ЧРП и получения обратной связи
        PU[i].ErrorxSwitchToVFD.Initialize(PU[i].rtrig_xSwitchToVFD.Q AND PU[i].xConditionToSwitchToVFD, PU[i].xStatusEnableVFD AND NOT PU[i].xStatusEnableBP, PU[i].xErrorLongTimeException_xSwitchToVFD, LONG_TIME_EXPECTATION_TIME);
        

        // Генерация состояния насоса в переменную типа INT (для передачи HMI)
        IF (NOT PU[i].xStatusEnableBP) AND (NOT PU[i].xStatusEnableVFD) AND (PU[i].iStatus <> 4) THEN
            PU[i].iStatus := 1;
        ELSIF (PU[i].xStatusEnableBP) AND (PU[i].xStatusEnableVFD) AND (PU[i].iStatus <> 4) THEN
            PU[i].iStatus := 2;
        ELSIF (PU[i].xStatusDry) OR (VFD[iVFD_Change].xFailure) THEN
            PU[i].iStatus := 4;
        END_IF;

        // Генерация ошибки получения сигнала о работе насоса (когда он уже включен)
        PU[i].ton_ErrorLostFeedbackSignal(
            IN:= (PU[i].Device.Power AND NOT PU[i].xStatusEnableBP) OR (PU[i].Device.PowerVFD AND (NOT PU[i].xStatusEnableVFD OR NOT VFD[iVFD_Change].xWork OR NOT VFD[iVFD_Change].Device.Power)), 
            PT:= PU_TIME_TO_AUTO_STOP_ERROR_LOST_FEEDBACK);
        IF PU[i].ton_ErrorLostFeedbackSignal.Q THEN PU[i].xErrorLostFeedbackSignal := TRUE; END_IF;

        // Запись ошибок в одну переменную для передачи на верхний уровень
        PU[i].xCommonError := 
            PU[i].xErrorLostFeedbackSignal 
            OR PU[i].xErrorEnableStatusVFD 
            OR PU[i].xErrorLongTimeException_xStop 
            OR PU[i].xErrorLongTimeException_xStartBP 
            OR PU[i].xErrorLongTimeException_xStartVFD
            OR PU[i].xErrorLongTimeException_xSwitchToBP
            OR PU[i].xStatusDry
            OR PU[i].xErrorLongTimeException_xSwitchToVFD;

        // Формирование сигнала готовности запуска от БП и от ЧРП
        PU[i].xReadyToStartBP := PU[i].xConditionToStartBP;
        PU[i].xReadyToStartVFD := PU[i].xConditionToStartVFD AND NOT Get_PU_VFD_Common();
        // Формирование (полного) сигнала о работе насоса от ЧРП
        PU[i].xWorkingFromVFD := PU[i].Device.PowerVFD AND VFD[iVFD_Change].xWork AND VFD[iVFD_Change].Device.Power;
        
        // --- Передача состояния по протоколу Modbus ---
    // 	PU[i].wStatus.VarByte[0].0 	:= 		PU[i].xReadyToStartVFD;
    // 	PU[i].wStatus.VarByte[0].1 	:= 		PU[i].xReadyToStartBP;
    // 	PU[i].wStatus.VarByte[0].2 	:= 		PU[i].xCommonError;
    // 	PU[i].wStatus.VarByte[0].3 	:= 		PU[i].xStatusManual;
    // 	PU[i].wStatus.VarByte[0].4 	:= 		PU[i].xStatusEnableVFD;
    // 	PU[i].wStatus.VarByte[0].5 	:= 		PU[i].xStatusEnableBP;
        PU[i].wCurrentSpeed.rTag 	:= 		VFD[iVFD_Change].Device.Frequency * 2;
        (*
        // --- Получение команд по протоколу Modbus ---
        PU[i].Auto_xStartVFD 			:= 	PU[i].Auto_cmdWord.VarByte[0].0;
        PU[i].Auto_xStop 				:= 	PU[i].Auto_cmdWord.VarByte[0].1;
        PU[i].Auto_xReset 				:= 	PU[i].Auto_cmdWord.VarByte[0].2;
        PU[i].Auto_xStartBP 			:= 	PU[i].Auto_cmdWord.VarByte[0].3;
        PU[i].Auto_xRequestLocalRemote 	:= 	PU[i].Auto_cmdWord.VarByte[0].4;
        PU[i].Auto_xSwitchToBP 			:= 	PU[i].Auto_cmdWord.VarByte[0].5;
        PU[i].Auto_xSwitchToVFD 		:= 	PU[i].Auto_cmdWord.VarByte[0].6;
        PU[i].Auto_xEmergencyStop 		:= 	PU[i].Auto_cmdWord.VarByte[0].7;
        *)

    END_FOR;
END_METHOD
(* Инициализация ЧРП *)
METHOD Init_VFD
    VAR
        i : INT;
    END_VAR

    CASE PLC_Mode OF
        0:
            // Передача команд триггерам
            VFD[2].rtrig_xSetToMain(CLK:= VFD[2].Auto_SetToMain, Q=> );
            VFD[1].rtrig_xSetToReserve(CLK:= VFD[1].Auto_SetToReserve, Q=> );
            // Передача задания частоты по свойству класса
            VFD[1].Device.Frequency := Auto_rSetFrequency;
            VFD[2].Device.Frequency := Auto_rSetFrequency;
        2:
            // Передача команд триггерам
            VFD[2].rtrig_xSetToMain(CLK:= VFD[2].Service_SetToMain, Q=> );
            VFD[1].rtrig_xSetToReserve(CLK:= VFD[1].Service_SetToReserve, Q=> );	
            // Передача задания частоты по свойству класса
            VFD[1].Device.Frequency := Service_rSetFrequency;
            VFD[2].Device.Frequency := Service_rSetFrequency;
    END_CASE
    // Передача выходной частоты по свойству класса
    VFD[1].qrFrequency := VFD[1].Device.Frequency;
    VFD[2].qrFrequency := VFD[2].Device.Frequency;
    // Передача масштабированного сигнала в модуль аналогового выхода 0_1000
    VFD[1].qiScaledFrequency_0_1000 := VFD[1].Device.ConvertationToAsignal_0_1000();
    VFD[2].qiScaledFrequency_0_1000 := VFD[2].Device.ConvertationToAsignal_0_1000();
    // Передача константы максимальной частоты
    VFD[1].Device.FrequencyMax := VFD_MAX_FREQ;
    VFD[2].Device.FrequencyMax := VFD_MAX_FREQ;
    // Передача сигнала питания на контакторы
    _0303_05_1KM8_qxOn := VFD[1].Device.Power;
    _0303_05_2KM8_qxOn := VFD[2].Device.Power;
    //
    VFD[1].xFailure := in_0303_05_1_ixVFD_Failure.qxSignal;
    VFD[1].xReady := in_0303_05_1_ixVFD_Ready.qxSignal;
    VFD[2].xFailure := in_0303_05_1_ixVFD_Failure.qxSignal;
    VFD[2].xReady := in_0303_05_1_ixVFD_Ready.qxSignal;


    FOR i := 1 TO 2 BY 1 DO
        VFD[i].wStatusOutFrequency.rTag := VFD[i].Device.Frequency;
    END_FOR
END_METHOD

(* Команды ЗРА *)
METHOD Commands_BY
    VAR
        i : INT;
    END_VAR

    FOR i := 1 TO BY_AMOUNT BY 1 DO
        CASE PLC_Mode OF
            0:
                // Передача команд триггерам (АВТО)
                Shutter[i].rtrig_xOpen(CLK:= Shutter[i].Auto_xOpen);
                Shutter[i].rtrig_xClose(CLK:= Shutter[i].Auto_xClose);
                Shutter[i].rtrig_xStop(CLK:= Shutter[i].Auto_xStop);
                Shutter[i].rtrig_xReset(CLK:= Shutter[i].Auto_xReset);
            2:
                // Передача команд триггерам (СЕРВИС)
                Shutter[i].rtrig_xOpen(CLK:= Shutter[i].Service_xOpen);
                Shutter[i].rtrig_xClose(CLK:= Shutter[i].Service_xClose);
                Shutter[i].rtrig_xStop(CLK:= Shutter[i].Service_xStop);
                Shutter[i].rtrig_xReset(CLK:= Shutter[i].Service_xReset);
        END_CASE;
        // Условия на открытие затвора
        Shutter[i].ConditionToxOpen := 
            NOT Shutter[i].xStatusOpen
            AND NOT Shutter[i].xStatusError
            AND Shutter[i].xStatusReady;
        // Условия на закрытие затвора
        Shutter[i].ConditionToxClose :=
            NOT Shutter[i].xStatusClosed
            AND NOT Shutter[i].xStatusError
            AND Shutter[i].xStatusReady;
        // Условие на выполнение команды СТОП
        Shutter[i].ConditionToxStop :=
            TRUE;
        // Условие на автоматическую остановку затвора
        Shutter[i].ConditionToxAutoStop :=
            Shutter[i].xErrorLongExpectationOpen
            OR Shutter[i].xErrorLongExpectationClose
            OR Shutter[i].xErrorLongExpectationStop
            OR (Shutter[i].Device.CloseMechanism.Power AND Shutter[i].xStatusClosed)
            OR (Shutter[i].Device.OpenMechanism.Power AND Shutter[i].xStatusOpen)
            OR Shutter[i].xStatusError;
        // Общие условия на исполнение команд
        Shutter_CTRL.AccessToClose := TRUE;
        Shutter_CTRL.AccessToOpen := TRUE;
        Shutter_CTRL.AccessToStop := TRUE;
        // Передача команд и устройства классу управления
            // Открытие
        Shutter_CTRL.Open(Shutter[i].rtrig_xOpen.Q AND Shutter[i].ConditionToxOpen, Shutter[i].Device);
            // Закрытие
        Shutter_CTRL.Close(Shutter[i].rtrig_xClose.Q AND Shutter[i].ConditionToxClose, Shutter[i].Device);
            // Остановка
        Shutter_CTRL.Stop(Shutter[i].rtrig_xStop.Q, Shutter[i].Device);
            // Автоматическая остановка
        Shutter_CTRL.Stop(Shutter[i].ConditionToxAutoStop, Shutter[i].Device);

        // Описание команды RESET 
        IF Shutter[i].rtrig_xReset.Q THEN
            Shutter[i].ErrorOpen.Reset();
            Shutter[i].ErrorClose.Reset();
            Shutter[i].ErrorStop.Reset();
        END_IF;
    END_FOR;
END_METHOD
(* Команды ПЛК *)
METHOD Commands_PLC
    PLC_cmd.rtrig_xcmdService_ChangetoAuto(CLK:= PLC_cmd.xcmdService_ChangetoAuto);
    PLC_cmd.rtrig_xcmdService_ChangetoService(CLK:= PLC_cmd.xcmdService_ChangetoService);
    PLC_cmd.rtrig_xcmdAuto_ChangetoAuto(CLK:= PLC_cmd.xcmdAuto_ChangetoAuto, Q=> );
    PLC_cmd.rtrig_xcmdAuto_ChangetoService(CLK:= PLC_cmd.xcmdAuto_ChangetoService, Q=> );
    PLC_cmd.rtrig_xcmdAuto_ResetErrorLostConnection(CLK:= PLC_cmd.xcmdAuto_ResetErrorLostConnection OR PLC_cmd.xcmdAuto_CommonReset);
    // Обработка команд от АСУТП
        // Переключение в режим АВТО
    IF PLC_cmd.rtrig_xcmdAuto_ChangetoAuto.Q AND PLC_Mode = 2 THEN
        PLC_Mode := 0;
    END_IF;
        // Переключение в режим СЕРВИС
    IF PLC_cmd.rtrig_xcmdAuto_ChangetoService.Q AND PLC_Mode = 0 THEN
        PLC_Mode := 2;
    END_IF;
        // Ресет ошибки связи
    IF PLC_cmd.rtrig_xcmdAuto_ResetErrorLostConnection.Q THEN
        PLC_Connection_Fault := FALSE;
        //xEmergencyStopCommonLostConnectionTimeOut := FASLE;
    END_IF;
    // Получение запроса на переключение ПЛК в режим сервис от HMI оператора
    IF PLC_Mode = 0 AND PLC_cmd.rtrig_xcmdService_ChangetoService.Q THEN
        PLC_cmd.xRequest_ChangeToService := TRUE;
    END_IF;
    // Осуществление разрешения на перевод ПЛК в режим сервис.
    IF PLC_Mode = 0 AND PLC_cmd.xAccess_ChangeToService THEN
        PLC_Mode := 2;
    END_IF;
    // Переключение режима ПЛК из СЕРВИС в АВТО по команде от HMI
    IF PLC_Mode = 2 AND PLC_cmd.rtrig_xcmdService_ChangetoAuto.Q THEN
        PLC_Mode := 0;
    END_IF;
    // При отсутствии связи с ПЛК АСУТП, команда на переключение ПЛК в режим СЕРВИС совершается напрямую
    IF PLC_Mode = 1 AND PLC_cmd.rtrig_xcmdService_ChangetoService.Q THEN
        PLC_Mode := 2;
    END_IF;
    // Моментальная остановка насосной станции по команде
    rtrig_xEmergencyStopCommon(CLK:= xcmdEmergencyStopCommon);
    IF rtrig_xEmergencyStopCommon.Q THEN
        xEmergencyStopCommon := TRUE;
    END_IF;
END_METHOD
(* Команды насосов *)
METHOD Commands_Pump
    VAR
        i : INT;
    END_VAR

    (* 	Обработка поступаемых команд, обработка условий и передача данных управляющему классу.
    * 	i - инкремент в цикле FOR, который проходит по каждому насосу отдельно,
    *	проверяя его условия
    *)
    FOR i := 1 TO PU_AMOUNT BY 1 DO
        // Обработка предпусковой звуковой сигнализации
        IF xSoundSirenOption THEN
            PU[i].cmdStartBP_StartSound(
                ixEnableSignal:= PU[i].rtrig_xStartBP.Q, 
                itFirstSoundTime:= tFirtSoundTime, 
                itPauseSoundTime:= tSoundPause, 
                itSecondSoundTime:= tSecondSoundTime, 
                qxSound=> PU[i].xSoundSirenSetSound);
                
            PU[i].cmdStartVFD_StartSound(
                ixEnableSignal:= PU[i].rtrig_xStartVFD.Q, 
                itFirstSoundTime:= tFirtSoundTime, 
                itPauseSoundTime:= tSoundPause, 
                itSecondSoundTime:= tSecondSoundTime, 
                qxSound=> PU[i].xSoundSirenSetSound);
        END_IF;

        // Пропуск команд через триггеры
        IF NOT xEmergencyStopCommonLostConnectionTimeOut THEN
            CASE PLC_Mode OF 
                0:	// Режим АВТО
                    PU[i].rtrig_xStartBP(CLK:= (PU[i].Auto_xStartBP AND NOT PU[i].xStatusManual) , Q=> );	
                    PU[i].rtrig_xStartVFD(CLK:= (PU[i].Auto_xStartVFD AND NOT PU[i].xStatusManual) OR (PU[i].Auto_xEnableLocalRemote AND PU[i].xManualStart AND PU[i].xStatusManual), Q=> );
                    PU[i].rtrig_xStop(CLK:= (PU[i].Auto_xStop AND NOT PU[i].xStatusManual) OR (PU[i].Auto_xEnableLocalRemote AND PU[i].xManualStop AND PU[i].xStatusManual), Q=> );
                    PU[i].rtrig_xSwitchToBP(CLK:= PU[i].Auto_xSwitchToBP AND NOT PU[i].xStatusManual, Q=> );
                    PU[i].rtrig_xSwitchToVFD(CLK:= PU[i].Auto_xSwitchToVFD AND NOT PU[i].xStatusManual, Q=> );
                    PU[i].rtrig_xReset(CLK:= PU[i].Auto_xReset, Q=> );
                    PU[i].rtrig_xEmergencyStop(CLK:= PU[i].Auto_xEmergencyStop);
                2:	// Режим СЕРВИС
                    PU[i].rtrig_xStartBP(CLK:= PU[i].Service_xStartBP AND NOT PU[i].xStatusManual, Q=> );	
                    PU[i].rtrig_xStartVFD(CLK:= (PU[i].Service_xStartVFD AND NOT PU[i].xStatusManual) OR (PU[i].xManualStart AND PU[i].xStatusManual), Q=> );
                    PU[i].rtrig_xStop(CLK:= PU[i].Service_xStop OR PU[i].xManualStop, Q=> );
                    PU[i].rtrig_xSwitchToBP(CLK:= PU[i].Service_xSwitchToBP AND NOT PU[i].xStatusManual, Q=> );
                    PU[i].rtrig_xSwitchToVFD(CLK:= PU[i].Service_xSwitchToVFD AND NOT PU[i].xStatusManual, Q=> );
                    PU[i].rtrig_xReset(CLK:= PU[i].Service_xReset, Q=> );
                    PU[i].rtrig_xEmergencyStop(CLK:= PU[i].Service_xEmergencyStop);
            END_CASE;
        END_IF;
        // * Индивидуальные условия выполнения команд по каждому насосу * //
        // Выполнение команды СТАРТ БП
        PU[i].xConditionToStartBP :=
            NOT PU[i].Device.Power
            AND NOT PU[i].Device.PowerVFD;    
        // Выполнение команды СТАРТ ЧРП                	
        PU[i].xConditionToStartVFD :=
            NOT PU[i].Device.Power								
            AND NOT PU[i].Device.PowerVFD;
        // Выполнение команды ПЕРЕКЛЮЧЕНИЕ НА БП
        PU[i].xConditionToSwitchToBP :=
            PU[i].Device.PowerVFD;
        // Выполнение команды ПЕРЕКЛЮЧЕНИЕ НА ЧРП
        PU[i].xConditionToSwitchToVFD :=
            PU[i].Device.Power;
        // Выполнение команды СТОП
        PU[i].xConditionToStop := TRUE;
        // Условия автоматической остановки конкретного насоса
        PU[i].xConditionToAutoStop := 
            PU[i].xErrorLongTimeException_xStartBP 
            OR PU[i].xErrorLongTimeException_xStartVFD 
            OR PU[i].xErrorLongTimeException_xSwitchToBP 
            OR PU[i].xErrorLongTimeException_xSwitchToVFD
            OR PU[i].xErrorLostFeedbackSignal
            OR PU[i].xStatusDry;
        // Мгновенная задача частоты при переходе на ЧРП (* Размещено здесь из-за конфликта очередности проверок *)
        IF PU[i].rtrig_xSwitchToVFD.Q AND PU[i].Device.Power AND NOT Get_PU_VFD_Common() THEN
            VFD[iVFD_Change].Device.Set_Frequency_Manual(VFD_CHANGE_BP_TO_VFD_FREQ);
        END_IF;
        
        // * Общие условия работы команд, не зависящие от выбора конкретного насоса * //
        // Условие на запуск от БП
        PU_CTRL.AccessToStart := TRUE;	
        // Условие на остановку (одинаково для контакторов ЧРП и БП)															
        PU_CTRL.AccessToStop := TRUE;		
        // Условие на запуск от ЧРП														
        PU_CTRL.AccessToStartVFD := NOT Get_PU_VFD_Common();	
        // Условие на переключение  с ЧРП на БП									
        PU_CTRL.AccessSwitchToStart := VFD[iVFD_Change].Device.Frequency >= VFD_FREQ_ACCESS_SWITCH_TO_BP;	
        // Условие на переключение с БП на ЧРП	
        PU_CTRL.AccessSwitchToVFD := NOT Get_PU_VFD_Common();

        // * Описание команд * //
        // Старт БП
        PU_CTRL.Start((NOT xSoundSirenOption AND PU[i].rtrig_xStartBP.Q) OR (xSoundSirenOption AND PU[i].cmdStartBP_StartSound.qxEndSignal) AND PU[i].xConditionToStartBP, PU[i].Device);
        // Старт от ЧРП	                                        	
        PU_CTRL.StartVFD((NOT xSoundSirenOption AND PU[i].rtrig_xStartVFD.Q) OR (xSoundSirenOption AND PU[i].cmdStartVFD_StartSound.qxEndSignal) AND PU[i].xConditionToStartVFD,PU[i].Device);											
        // Переключение с ЧРП на БП                             	
        PU_CTRL.SwitchToStart(PU[i].rtrig_xSwitchToBP.Q AND PU[i].xConditionToSwitchToBP, PU[i].Device);											
        // Переключение с БП на ЧРП                             	
        PU_CTRL.SwitchToVFD(PU[i].rtrig_xSwitchToVFD.Q AND PU[i].xConditionToSwitchToVFD, PU[i].Device);											
        // Команда на остановку контактора (БП)
        PU_CTRL.Stop(PU[i].rtrig_xStop.Q AND PU[i].xConditionToStop, PU[i].Device);
        // Команда на остановку контактора (ЧРП)
        PU_CTRL.StopVFD(PU[i].rtrig_xStop.Q AND PU[i].xConditionToStop, PU[i].Device);
        // Автоматическая остановка контактора насоса (БП)
        PU_CTRL.Stop(PU[i].xConditionToAutoStop, PU[i].Device);
        // Автоматическая остановка контактора насоса (ЧРП)
        PU_CTRL.StopVFD(PU[i].xConditionToAutoStop, PU[i].Device);
        // Аварийная остановка насоса (по команде) - БП
        PU_CTRL.Stop(PU[i].rtrig_xEmergencyStop.Q, PU[i].Device);
        // Аварийная остановка насоса (по команде) - ЧРП
        PU_CTRL.StopVFD(PU[i].rtrig_xEmergencyStop.Q, PU[i].Device);
        
        // Описание команды RESET
        IF PU[i].rtrig_xReset.Q THEN
            PU[i].ErrorxStartBP.Reset();
            PU[i].ErrorxStartVFD.Reset();
            PU[i].ErrorxStop.Reset();
            PU[i].ErrorxSwitchToBP.Reset();
            PU[i].ErrorxSwitchToVFD.Reset();
            PU[i].xErrorLostFeedbackSignal := FALSE;
        END_IF;
    END_FOR
END_METHOD
(* Команды ЧРП *)
METHOD Commands_VFD
    VAR
        i : INT;
    END_VAR

    // Передача параметра шага плавной задачи частоты и цикла с регулярным импульсом
    VFD[1].Device.Calculate_Frequency(VFD_CYCLE_STEP, rtrig_UpdateCyclePulse.Q);
    VFD[2].Device.Calculate_Frequency(VFD_CYCLE_STEP, rtrig_UpdateCyclePulse.Q);
    // Условия автоматического перехода на резервный и основной частотник
    VFD[1].ConditionSetToReserve := 
        VFD[1].xFailure
        AND NOT VFD[2].xFailure;
    VFD[2].ConditionSetToMain :=
        VFD[2].xFailure
        AND NOT VFD[1].xFailure;
    // Условия запуска и остановки ЧРП
    VFD_CTRL.AccessToStart := NOT VFD[iVFD_Change].xFailure AND VFD[iVFD_Change].xReady;
    VFD_CTRL.AccessToStop := TRUE;
    // Условие автоматической остановки ЧРП
    VFD[1].ConditionAutoStop :=
        VFD[1].xFailure;
    VFD[2].ConditionAutoStop :=
        VFD[2].xFailure;
    VFD_CTRL.Stop(VFD[iVFD_Change].ConditionAutoStop, VFD[iVFD_Change].Device);
    // Условия продолжения вычислений частоты
    VFD[1].Device.AcessToCalculate := VFD[1].Device.Power;
    VFD[2].Device.AcessToCalculate := VFD[2].Device.Power;
    // Передача команды для запуска и остановки ЧРП
    VFD_CTRL.Start(Get_PU_VFD_Common(), VFD[iVFD_Change].Device);
    VFD_CTRL.Stop(NOT Get_PU_VFD_Common(), VFD[iVFD_Change].Device);
    // Условия автоматического сброса выходной частоты до нуля
    VFD_CTRL.ResetFrequency(NOT Get_PU_VFD_Common(), VFD[iVFD_Change].Device);
    // Алгоритм переключения основного и резервного ЧРП
    IF (VFD[1].rtrig_xSetToReserve.Q OR VFD[1].ConditionSetToReserve) AND iVFD_Change = 1 THEN
        VFD[2].Device.Set_Frequency_Manual(VFD[1].Device.Frequency);
        iVFD_Change := 2;
        VFD[1].Device.Set_Frequency_Manual(0);
    ELSIF (VFD[2].rtrig_xSetToMain.Q OR VFD[2].ConditionSetToMain) AND iVFD_Change = 2 THEN
        VFD[1].Device.Set_Frequency_Manual(VFD[2].Device.Frequency);
        iVFD_Change := 1;
        VFD[2].Device.Set_Frequency_Manual(0);
    END_IF;
    // Переключение питания на активный ЧРП при наличии активных насосов от ЧРП
    VFD_CTRL.SwitchPower(iVFD_Change = 2 AND Get_PU_VFD_Common(), VFD[1].Device, VFD[2].Device);
    VFD_CTRL.SwitchPower(iVFD_Change = 1 AND Get_PU_VFD_Common(), VFD[2].Device, VFD[1].Device);
END_METHOD

(* Мгновенная аварийная остановка насосной станции *)
METHOD EmergencyStopCommon
    VAR
        i : INT;
        j : INT;
    END_VAR

    VFD[1].Device.Set_Frequency_Manual(0);
    VFD[1].Device.Frequency := 0;
    VFD[2].Device.Set_Frequency_Manual(0);
    VFD[2].Device.Frequency := 0;

    FOR i := 1 TO PU_AMOUNT BY 1 DO
        PU[i].Device.Set_Power(FALSE);
        PU[i].Device.Set_Power_VFD(FALSE);
    END_FOR;

    FOR j := 1 TO BY_AMOUNT BY 1 DO
        Shutter[j].Device.Close();
    END_FOR;

END_METHOD

(* Алгоритм поэтапной остановки насосной станции при потере связи с АСУТП *)
METHOD LostConnectionStopProcess
	VFD[1].Device.Frequency := 0;
	VFD[2].Device.Frequency := 0;
	IF EmergencyStopLostConnection_iCurrentPU = -1 THEN
		// Если есть работающий насос от ЧРП — первым его выключаем
		IF Get_PU_VFD_Common() THEN
			PU[Get_PU_VFD_Number()].Device.Set_Power_VFD(FALSE);
			Shutter[Get_PU_VFD_Number()].Device.Close();
		END_IF;
		// Запускаем задержку после первого действия
		EmergencyStopLostConnection_tDelay(IN := TRUE, PT := EMERGENCY_STOP_PU_DELAY_TIME);
		EmergencyStopLostConnection_xDelayRun := TRUE;
		EmergencyStopLostConnection_iCurrentPU := 0; // Переходим к следующему шагу
		RETURN; // Ждём задержку перед следующим насосом
	END_IF;
	
	// Если ждём задержку — просто ждём
	IF EmergencyStopLostConnection_xDelayRun THEN
		EmergencyStopLostConnection_tDelay(IN := TRUE, PT := EMERGENCY_STOP_PU_DELAY_TIME);
		IF EmergencyStopLostConnection_tDelay.Q THEN
			EmergencyStopLostConnection_tDelay(IN := FALSE);    // Сброс таймера
			EmergencyStopLostConnection_xDelayRun := FALSE;     // Задержка закончена
		ELSE
			RETURN; // Пока задержка не закончилась — выходим
		END_IF;
	END_IF;
	
	// ===== Поиск и остановка следующего включённого насоса =====
	REPEAT
		EmergencyStopLostConnection_iCurrentPU := EmergencyStopLostConnection_iCurrentPU + 1;
	UNTIL (EmergencyStopLostConnection_iCurrentPU > PU_AMOUNT) OR PU[EmergencyStopLostConnection_iCurrentPU].Device.Power
	END_REPEAT;
	
	// Если нашли работающий насос — выключаем и запускаем задержку
	IF (EmergencyStopLostConnection_iCurrentPU <= PU_AMOUNT) AND PU[EmergencyStopLostConnection_iCurrentPU].Device.Power THEN
		PU[EmergencyStopLostConnection_iCurrentPU].Device.Set_Power(FALSE);
		Shutter[EmergencyStopLostConnection_iCurrentPU].Device.Close();
		EmergencyStopLostConnection_tDelay(IN := TRUE, PT := EMERGENCY_STOP_PU_DELAY_TIME);
		EmergencyStopLostConnection_xDelayRun := TRUE;
	END_IF;
	
	// Если все насосы обработаны — сброс в исходное состояние
	IF EmergencyStopLostConnection_iCurrentPU > PU_AMOUNT THEN
		EmergencyStopLostConnection_iCurrentPU := -1;
	END_IF

    (* Версия работы алгорима с плавным отключением насосов через переключение на контактор ЧРП и понижение частоты
    FOR i := 1 TO PU_AMOUNT BY 1 DO
        // Если никакой насос не подключен в ЧРП
        IF NOT Get_PU_VFD_Common() THEN
            // Если насос имеет питание от БП, он переходит на контактор ЧРП
            IF PU[i].Device.Power THEN
                PU[i].Device.Set_Power(FALSE);
                PU[i].Device.Set_Power_VFD(TRUE);
                VFD[iVFD_Change].Device.Set_Frequency_Manual(VFD_MAX_FREQ);
            END_IF;
        END_IF;
        // Условия перехода к следующему насосу после полной остановки текущего насоса
        IF Get_PU_VFD_Common() AND VFD[iVFD_Change].Device.Frequency = 0 THEN
            PU[Get_PU_VFD_Number()].Device.Set_Power_VFD(FALSE);
        END_IF
    END_FOR;
    *)
END_METHOD

(* Контроль связи с ПЛК АСУТП *)
METHOD PLC_ConnectionControl
    // Таймеры контроля LifeBit
    ton_PLC_LifeBit_Control_Off(
        IN := NOT PLC_LifeBit,
        PT := LIFEBIT_CONNECTION_TIME
    );
    ton_PLC_LifeBit_Control_On(
        IN := PLC_LifeBit,
        PT := LIFEBIT_CONNECTION_TIME
    );

    // SR-триггер для фиксации состояния связи
    sr_PLC_LifeBit_Control(
        SET1 := NOT (ton_PLC_LifeBit_Control_Off.Q OR ton_PLC_LifeBit_Control_On.Q),
        RESET := ton_PLC_LifeBit_Control_Off.Q OR ton_PLC_LifeBit_Control_On.Q
    );

    // Если связь потеряна — фиксируем ошибку и переводим ПЛК в режим "Обрыв связи"
    IF NOT sr_PLC_LifeBit_Control.Q1 THEN
        PLC_Connection_Fault := TRUE;
        PLC_Mode := 1;
    END_IF;

    // Если связь восстановлена — снимаем ошибку и возвращаем режим "Авто"
    PLC_Connection_Ok := sr_PLC_LifeBit_Control.Q1;
    IF PLC_Mode = 1 AND PLC_Connection_Ok THEN
        PLC_Mode := 0;
    END_IF;

    // Таймер аварийной остановки по потере связи
    ton_LostConnectionEmergencyStopTimeOut(
        IN := PLC_Mode = 1,
        PT := LOST_CONNECTION_EMERGENCY_STOP_TIME
    );

    // Если таймер аварийной остановки сработал — формируем команду аварийной остановки
    IF ton_LostConnectionEmergencyStopTimeOut.Q THEN
        xEmergencyStopCommonLostConnectionTimeOut := TRUE;
    END_IF;
END_METHOD

(* Сброс всех ошибок насосов и затворов *)
METHOD ResetAllErrors
    VAR
        i : INT;
        j : INT;
    END_VAR

    // Сброс ошибок насосов
    FOR i := 1 TO PU_AMOUNT DO
        PU[i].xErrorLongTimeException_xStartBP := FALSE;
        PU[i].xErrorLongTimeException_xStartVFD := FALSE;
        PU[i].xErrorLongTimeException_xSwitchToBP := FALSE;
        PU[i].xErrorLongTimeException_xSwitchToVFD := FALSE;
        PU[i].xErrorLongTimeException_xStop := FALSE;
        PU[i].xErrorLostFeedbackSignal := FALSE;
        PU[i].xErrorEnableStatusVFD := FALSE;
        PU[i].xCommonError := FALSE;
    END_FOR

    // Сброс ошибок затворов
    FOR j := 1 TO BY_AMOUNT DO
        Shutter[j].xStatusError := FALSE;
        Shutter[j].xLongExpectationOpen := FALSE;
        Shutter[j].xErrorLongExpectationClose := FALSE;
        Shutter[j].xErrorLongExpectationStop := FALSE;
        Shutter[j].ErrorOpen.Q := FALSE;
        Shutter[j].ErrorClose.Q := FALSE;
        Shutter[j].ErrorStop.Q := FALSE;
    END_FOR

    // Сброс аварийных сигналов
    xEmergencyStopCommon := FALSE;
    xEmergencyStopCommonLostConnectionTimeOut := FALSE;
    PLC_Connection_Fault := FALSE;
END_METHOD

END_PROGRAM