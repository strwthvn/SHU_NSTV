FUNCTION_BLOCK FB_StartSiren
VAR_INPUT
	ixEnableSignal : BOOL; 			// Сигнал на запуск
	itFirstSoundTime : TIME;		// Время работы первого звукового сигнала
	itPauseSoundTime : TIME;		// Время работы первого звукового сигнала
	itSecondSoundTime : TIME;		// Время работы первого звукового сигнала
END_VAR
VAR_OUTPUT
	qxSound : BOOL;			// Выходной сигнал на подачу звука
	qxEndSignal : BOOL;		// Выходной сигнал об окончании работы ФБ
END_VAR
VAR
	step : INT := 0;
	xProcess : BOOL;
	ton_soundProcess : TON;
END_VAR

IF ixEnableSignal THEN
	xProcess := TRUE;
	step := 1;
END_IF;

CASE step OF
	1:
		ton_soundProcess.PT := itFirstSoundTime;
		qxSound := TRUE;
		IF ton_soundProcess.Q THEN xProcess := FALSE; step := 2; END_IF;
	2: 
		qxSound := FALSE;
		ton_soundProcess.PT := itPauseSoundTime;
		xProcess := TRUE;
		IF ton_soundProcess.Q THEN xProcess := FALSE; step := 3; END_IF;
	3: 
		qxSound := TRUE;
		ton_soundProcess.PT := itSecondSoundTime;
		xProcess := TRUE;
		IF ton_soundProcess.Q THEN 
			xProcess := FALSE; 
			qxSound := FALSE; 
			step := 0; 
		END_IF;
END_CASE;
ton_soundProcess(IN:= xProcess);
qxEndSignal := ton_soundProcess.Q AND step = 3;
END_FUNCTION_BLOCK