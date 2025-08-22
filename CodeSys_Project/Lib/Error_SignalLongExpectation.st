FUNCTION_BLOCK Error_SignalLongExpectation
    VAR_INPUT
        ixExecuteSignal : BOOL;
        ixFeedbackSignal : BOOL;
        T : TIME;
    END_VAR
    VAR_OUTPUT
        Q : BOOL;
    END_VAR
    VAR
        ton_WorkProcess : TON;
        rs_WorkProcess : RS;
        xWorkProcess : BOOL;
        xReset : BOOL;
    END_VAR

    ton_WorkProcess(IN:= xWorkProcess, PT:= T, Q=> Q, ET=> );

    rs_WorkProcess(SET:= ixExecuteSignal, RESET1:= ixFeedbackSignal OR xReset, Q1=>xWorkProcess );

    IF xReset THEN
        Q := FALSE;
        xWorkProcess := FALSE;
        rs_WorkProcess.RESET1 := TRUE;	
    END_IF;
