INTERFACE BasicControlCommands

METHOD Start
VAR_INPUT
	access : BOOL;
	device : BasicControl;
END_VAR

METHOD Stop
VAR_INPUT
	access: BOOL;
	device : BasicControl;
END_VAR
