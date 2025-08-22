TYPE Struct_BY_ModbusRef :
STRUCT
	RemoteMode       :  BOOL;
	LocalMode        :  BOOL;
    OpenedPosition   :  BOOL;
    ClosedPosition   :  BOOL;
    SetPointReached  :  BOOL;
    NotReadyInd      :  BOOL;
    RunningOpen      :  BOOL;
    RunningClose     :  BOOL;s
    ProhibitLocalAct :  BOOL;
    FaultInd         :  BOOL;
END_STRUCT
END_TYPE
