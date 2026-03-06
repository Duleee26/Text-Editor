.386
.model flat, stdcall
;***************************** Configuration.inc *************************************************
; @brief:
;	This fails contains everything regarding text editor setting :
;	Parsing config.txt file
;	Initialize settings struct
;	Implement those settings to text editor 
;
;


;********************** Data for Text Editor Settings **********************************
MAX_PATH_LENGTH EQU   		260						; Max length of working Directory string
MAX_COLOR_LENGTH EQU		12						; Longest string for color name that we can use is 12
CONFIGURATION_FIELDS EQU    3						; Number of configurations that can be done (Numbers of elements of structure)
	
configurationParameters_t STRUCT
	work_dir BYTE (MAX_PATH_LENGTH + 1) DUP(0)			; Name of the file where are all text file located
	letterColor BYTE (MAX_COLOR_LENGTH + 1) DUP(0)		; Colors of printed character 
	backroundColor BYTE (MAX_COLOR_LENGTH + 1) DUP(0)		; Color of terminal backround
configurationParameters_t ENDS	


; Macro that translates string-> coloro Enum
IF_COLOR_EQ MACRO inputStr, constStr, retValue
LOCAL skipLabel

    INVOKE Str_compare,  inputStr, ADDR constStr
    jnz skipLabel

    mov eax, retValue
    ret

skipLabel:
ENDM

;**********************************************************************************
; Name: InitializeSettings
;
; Procedure Initialize settings struct by parsing config.txt file (every line = one member of configurationParameters_t Struct)
;
; Receives: string name of the configuration file
;
; Returns: Returns succes status through EAX register
;
; Registers changed: To be updated
;********************************************************************************** 
	InitializeSettings PROTO,
			configFile: PTR BYTE,

;**********************************************************************************
; Name: AplySettings
;
; Procedure Aply changes that are written in settingsInfo Structure
;
; Receives: NONE
;
; Returns: NONE
;
; Registers changed: To be updated
;********************************************************************************** 
	AplySettings PROTO
