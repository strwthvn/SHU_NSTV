TYPE Struct_PLC_Commands :
STRUCT
	// Команды от HMI (сервис)
	xcmdService_ChangetoAuto, xcmdService_ChangetoService, xcmdService_ResetErrorLostConnection, xcmdService_CommonReset : BOOL;
	// Команда от АСУТП (АВТО)
	xcmdAuto_ChangetoAuto, xcmdAuto_ChangetoService, xcmdAuto_ResetErrorLostConnection, xcmdAuto_CommonReset : BOOL;
	rtrig_xcmdService_ChangetoAuto, rtrig_xcmdService_ChangetoService, rtrig_xcmdService_ResetErrorLostConnection, rtrig_xcmdService_CommonReset : R_TRIG;
	rtrig_xcmdAuto_ChangetoAuto, rtrig_xcmdAuto_ChangetoService, rtrig_xcmdAuto_ResetErrorLostConnection, rtrig_xcmdAuto_CommonReset : R_TRIG;
	// Сигналы от АСУТП
	xAccess_ChangeToService : BOOL;
	// Сигнал для АСУТП
	xRequest_ChangeToService : BOOL;
END_STRUCT
END_TYPE
