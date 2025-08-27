FUNCTION_BLOCK FB_Error_SignalLongExpectation
VAR
    _execute : BOOL; // Флаг выполнения
    _feedback : BOOL; // Флаг обратной связи
    _timeout : TIME; // Таймаут ожидания

    _error : BOOL; // Флаг ошибки
    _error_message : STRING; // Сообщение об ошибке
    
    // Добавляем флаг отмены для корректной обработки
    _cancel_requested : BOOL; // Флаг запроса отмены

    _sr_waiting_feedback : SR;
    _ton_waiting_feedback : TON; // Таймер ожидания обратной связи
    _rtrig_execute : R_TRIG; // Растущий фронт команды выполнения
    _ftrig_feedback : F_TRIG; // Фронт обратной связи
END_VAR

// Обработка отмены в начале цикла
IF _cancel_requested THEN
    _cancel_requested := FALSE;
    _execute := FALSE; // Сбрасываем execute
    // Остальная логика отмены обработается ниже
END_IF

// Фронт команды execute
_rtrig_execute(CLK := _execute);

// SR-триггер для управления состоянием ожидания обратной связи
_sr_waiting_feedback(
    SET1 := _rtrig_execute.Q AND NOT _error AND NOT _cancel_requested, 
    RESET := _feedback OR _error OR _cancel_requested
);

// Таймер ожидания обратной связи
// Важно: таймер сбрасывается когда IN становится FALSE
_ton_waiting_feedback(
    IN := _sr_waiting_feedback.Q1 AND NOT _cancel_requested,
    PT := _timeout
);

// Формирование ошибки по истечении таймаута
// Добавляем проверку на отмену
IF _ton_waiting_feedback.Q AND NOT _error AND NOT _cancel_requested THEN
    _error := TRUE;
END_IF

// Обратный фронт обратной связи для дополнительной обработки
_ftrig_feedback(CLK := _feedback);

(* Установка флага выполнения *)
METHOD SetExecute
    VAR_INPUT
        execute : BOOL; // Флаг выполнения
    END_VAR

    _execute := execute;
END_METHOD

(* Установка флага обратной связи *)
METHOD SetFeedback
    VAR_INPUT
        feedback : BOOL; // Флаг обратной связи
    END_VAR

    _feedback := feedback;
END_METHOD

(* Установка таймаута ожидания *)
METHOD SetTimeout
    VAR_INPUT
        timeout : TIME; // Таймаут ожидания
    END_VAR

    _timeout := timeout;
END_METHOD

(* Установка сообщения об ошибке *)
METHOD SetErrorMessage
    VAR_INPUT
        error_message : STRING; // Сообщение об ошибке
    END_VAR

    _error_message := error_message;
END_METHOD

(* Получение сообщения об ошибке *)
METHOD GetErrorMessage : STRING
    GetErrorMessage := _error_message;
END_METHOD

(* Получение сигнала ошибки *)
METHOD GetError : BOOL
    GetError := _error;
END_METHOD

(* Сброс ошибки - улучшенная версия *)
METHOD Reset
    _error := FALSE;
    _execute := FALSE;
    _feedback := FALSE;
    _cancel_requested := TRUE; // Устанавливаем флаг отмены
    
    // Принудительно вызываем SR-триггер со сбросом
    _sr_waiting_feedback(SET1 := FALSE, RESET := TRUE);
    
    // Принудительно сбрасываем таймер
    _ton_waiting_feedback(IN := FALSE, PT := _timeout);
    _ton_waiting_feedback.ET := T#0s; // Сбрасываем накопленное время (если доступно)
    
    // Сбрасываем триггеры
    _rtrig_execute(CLK := FALSE);
    _ftrig_feedback(CLK := FALSE);
END_METHOD

(* Получение состояния ожидания *)
METHOD IsWaiting : BOOL
    IsWaiting := _sr_waiting_feedback.Q1 AND NOT _cancel_requested;
END_METHOD

(* Получение оставшегося времени ожидания *)
METHOD GetRemainingTime : TIME
    IF _ton_waiting_feedback.ET < _timeout THEN
        GetRemainingTime := _timeout - _ton_waiting_feedback.ET;
    ELSE
        GetRemainingTime := T#0s;
    END_IF
END_METHOD

(* Получение прошедшего времени ожидания *)
METHOD GetElapsedTime : TIME
    GetElapsedTime := _ton_waiting_feedback.ET;
END_METHOD

(* Комплексная инициализация блока *)
METHOD Initialize
    VAR_INPUT
		execute : BOOL;
		feedback : BOOL;
		error : REFERENCE TO BOOL;
		timeout : TIME;
    END_VAR

    SetExecute(execute);
    SetFeedback(feedback);
    error := GetError();
    SetTimeout(timeout);

END_METHOD

(* Проверка готовности к новой команде *)
METHOD IsReady : BOOL
    IsReady := NOT _sr_waiting_feedback.Q1 AND NOT _error AND NOT _cancel_requested;
END_METHOD

(* Получение статуса выполнения в текстовом виде *)
METHOD GetStatus : STRING
    IF _cancel_requested THEN
        GetStatus := 'CANCELLING';
    ELSIF _error THEN
        GetStatus := 'ERROR';
    ELSIF _sr_waiting_feedback.Q1 THEN
        GetStatus := 'WAITING';
    ELSE
        GetStatus := 'READY';
    END_IF
END_METHOD

(* Отмена текущего ожидания - улучшенная версия *)
METHOD Cancel
    // Устанавливаем флаг отмены
    _cancel_requested := TRUE;
    
    // Немедленно сбрасываем execute чтобы предотвратить новый запуск
    _execute := FALSE;
    
    // Принудительно вызываем SR-триггер со сбросом
    _sr_waiting_feedback(SET1 := FALSE, RESET := TRUE);
    
    // Принудительно сбрасываем таймер несколько раз для гарантии
    _ton_waiting_feedback(IN := FALSE, PT := _timeout);
    
    // Сбрасываем триггеры
    _rtrig_execute(CLK := FALSE);
END_METHOD

END_FUNCTION_BLOCK