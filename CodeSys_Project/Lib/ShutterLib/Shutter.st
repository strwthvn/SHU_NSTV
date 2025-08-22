FUNCTION_BLOCK Shutter IMPLEMENTS BasicControl_OpenClose
VAR_INPUT
END_VAR
VAR_OUTPUT
END_VAR
VAR
	OpenMechanism : ShutterOpenMechanism;
	CloseMechanism : ShutterCloseMechanism;
END_VAR

METHOD Close
    CloseMechanism.Set_Power(TRUE);	// Включаем механизм закрытия
    OpenMechanism.Set_Power(FALSE);	// Выключаем механизм открытия
END_METHOD

METHOD Open
    OpenMechanism.Set_Power(TRUE);	// Включаем механизм открытия
    CloseMechanism.Set_Power(FALSE);	// Выключаем механизм закрытия
END_METHOD

METHOD Stop 
    OpenMechanism.Set_Power(FALSE);	// Выключаем механизм открытия
    CloseMechanism.Set_Power(FALSE);	// Выключаем механизм закрытия
END_METHOD
END_FUNCTION_BLOCK