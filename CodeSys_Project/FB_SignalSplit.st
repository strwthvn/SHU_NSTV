FUNCTION_BLOCK FB_SignalSplit
VAR_INPUT
	ixAutoSignal : BOOL;
	ixServiceSignal : BOOL;
	
	irAutoSignal : REAL;
	irServiceSignal : REAL;
	
	iiPLCMode : INT;
END_VAR
VAR_OUTPUT
	qxSignal : BOOL;
	qrSignal : REAL;
END_VAR
VAR
END_VAR

CASE iiPLCMode OF
	0: qxSignal := ixAutoSignal; qrSignal := irAutoSignal;
	2: qxSignal := ixServiceSignal; qrSignal := qrSignal;
END_CASE;