INCLUDE Irvine32.inc
include macros.inc
INCLUDE Configuration.inc
ReadColorString PROTO, colorName: PTR BYTE	
; Color name strings
.const

	BLACK_STR           BYTE "BLACK",        0
	WHITE_STR           BYTE "WHITE",        0
	BROWN_STR           BYTE "BROWN",        0
	YELLOW_STR          BYTE "YELLOW",       0
	BLUE_STR            BYTE "BLUE",         0
	GREEN_STR           BYTE "GREEN",        0
	CYAN_STR            BYTE "CYAN",         0
	RED_STR             BYTE "RED",          0
	MAGENTA_STR         BYTE "MAGENTA",      0
	GRAY_STR            BYTE "GRAY",         0

	LIGHTBLUE_STR       BYTE "LIGHTBLUE",    0
	LIGHTGREEN_STR      BYTE "LIGHTGREEN",   0
	LIGHTCYAN_STR       BYTE "LIGHTCYAN",    0
	LIGHTRED_STR        BYTE "LIGHTRED",     0
	LIGHTMAGENTA_STR    BYTE "LIGHTMAGENTA", 0
	LIGHTGRAY_STR       BYTE "LIGHTGRAY",    0



	MAX_FILE_SIZE EQU 1024					; Max size of buffer where file content will be written

.data
	; Trebalo bi ovo promeniti da ne bude fajl hendler u ovom fajlu (Poboljsati)
	
	settingsInfo configurationParameters_t <>			; Information from configuration.txt file
	public settingsInfo									; Make variable extern (can be used in main.asm file)

	fileHandle 	  DWORD ?							; Pointer to file
	fileBuffer    BYTE MAX_FILE_SIZE + 1 DUP(?)		; Buffer
	bytesRead  	  DWORD 0							; How many characters we read from config.txt file
	temp1		  BYTE (MAX_PATH_LENGTH + 1) DUP(?) ; Helper Variable for parsing file

.code
	InitializeSettings PROC USES edx ecx edi esi,
			configFile:			PTR BYTE,
		
		mov edx, configFile
		call OpenInputFile
		
		cmp eax, INVALID_HANDLE_VALUE
		jne read_file

		mWrite <"Error: Failed to open Text Editor (Couldn't find config file",0Dh,0Ah>
		mov eax, INVALID_HANDLE_VALUE
		ret

		read_file:
		mov fileHandle,eax
		mov edx, OFFSET fileBuffer
		mov ecx, MAX_FILE_SIZE
		call ReadFromFile
		jnc BufferFilled
		Call WriteWindowsMsg
		mov eax, INVALID_HANDLE_VALUE
		ret
		
		; Parse file to lines (every Line is one element of struct configurationParameters_t)
		BufferFilled:
		
		mov bytesRead, eax 					; If everything went correctly eax register will tell how much bytes where read
		mov fileBuffer[eax], 0				; Add null to end of buffer last element will have addres bytesRead + OFFSET fileBuffer
		
		
		mov edi, 0							; Index for destination (Structure strings)
		mov esi, 0 							; Index for source (Buffer String)
		mov ecx, 0							; Counts how many struct elements we changed
		
		.WHILE ecx < CONFIGURATION_FIELDS
			mov bl , fileBuffer[esi]				; Register next char in buffer
			.IF bl == 0Dh || bl == 0				; If char ('\n') or EOF save temp1 to struct, we arrived to lineBreak or last argument
				.IF bl == 0 && ecx < (CONFIGURATION_FIELDS - 1)		;If we are at the end of the file ecx should have index value of last element in struct, if not that means user didnt put enough argument in file
					mWrite <"Error: Failed to open Text Editor: Not enough arguments in config.txt",0Dh,0Ah>
					mov  eax,fileHandle
					call CloseFile
					mov eax, INVALID_HANDLE_VALUE
					ret
				.ENDIF
				inc esi								; Skip carriage return (goes with 0dh and  that why we have additional increment)
				mov temp1[edi],0					; Add Null to string 
				mov edi, 0 							; Reset temp1 index
				
				.IF ecx == 0
					INVOKE Str_copy,
							ADDR temp1,
							ADDR settingsInfo.letterColor
				.ELSEIF ecx == 1
					INVOKE Str_copy,
							ADDR temp1,
							ADDR settingsInfo.backroundColor
					
				.ELSEIF ecx == 2
				; Check If the length of data_path not exceeds MAX_LENGTH
					mov  edx,OFFSET temp1
					call StrLength
					cmp eax, MAX_PATH_LENGTH
					ja  PathTooLong
					
					INVOKE Str_copy,
							ADDR temp1,
							ADDR settingsInfo.work_dir
				.ELSE
					mWrite <"Error: To many arguments in config.txt)",0Dh,0Ah>
					mov eax ,INVALID_HANDLE_VALUE 		; Return with error Code
					mov  eax,fileHandle
					call CloseFile
					ret
				.ENDIF
				inc ecx								; Increment for every struct done
			.ELSE
				mov temp1[edi],bl
				inc edi
			.ENDIF
			inc esi
		.ENDW
		; Check if we read whole file IF not that means that user wrote to many arguments
		sub esi,2			; We don't want to include '0' char as read byte
		cmp esi, bytesRead
		jnz To_many_Arguments
		mov  eax,fileHandle
		call CloseFile
		ret
		To_many_Arguments:
		mWrite <"Error: Failed to open Text Editor: To many arguments in config.txt",0Dh,0Ah>
		mov eax, INVALID_HANDLE_VALUE
		mov  eax,fileHandle
		call CloseFile
		ret
		PathTooLong:
		mWrite <"Error: Path of Working Directory in config.txt is too long!",0Dh,0Ah>
		mov eax, INVALID_HANDLE_VALUE
		mov  eax,fileHandle
		call CloseFile
		ret
	InitializeSettings ENDP

	AplySettings PROC USES EAX EBX

    INVOKE ReadColorString, ADDR settingsInfo.letterColor
    .IF eax == INVALID_HANDLE_VALUE
        jmp return
    .ENDIF

    mov ebx, eax        ; EBX = foreground

    INVOKE ReadColorString, ADDR settingsInfo.backroundColor
    .IF eax == INVALID_HANDLE_VALUE
        jmp return
    .ENDIF

    mov edx, eax        ; EDX = backround

    mov eax, edx
    shl eax, 4          ; background = high 4 bits

    or eax, ebx         ; add foreground

    call SetTextColor

return:
    ret

AplySettings ENDP


;**********************************************************************************
; Name: ReadColorString
;
; Procedure Translate from string to Color Enum (for setTextColor Procedure)
;
; Receives: Pointer to color name string
;
; Returns: Returns color through EAX
;
; Registers changed: To be updated
;********************************************************************************** 
; black, white, brown, yellow, blue, green, cyan, red, magenta, gray, lightBlue, lightGreen, lightCyan, lightRed, lightMagenta, and lightGray.
	ReadColorString PROC,
			colorName: PTR BYTE	,			; Pointer to string that represents name of the color
	; Make all characters in string caps (red -> RED)	
		INVOKE Str_ucase,  colorName
		; String to Irvine Color Enum
		; Ovo mora da se popravi ( Ubaciti sve stringove )
		IF_COLOR_EQ  colorName, BLACK_STR, black
		IF_COLOR_EQ  colorName, WHITE_STR, white
		IF_COLOR_EQ  colorName, BROWN_STR, brown
		IF_COLOR_EQ  colorName, YELLOW_STR, yellow
		IF_COLOR_EQ  colorName, BLUE_STR, blue
		IF_COLOR_EQ  colorName, GREEN_STR, green
		IF_COLOR_EQ  colorName, CYAN_STR, cyan
		IF_COLOR_EQ  colorName, RED_STR, red
		IF_COLOR_EQ  colorName, MAGENTA_STR, magenta
		IF_COLOR_EQ  colorName, GRAY_STR, gray
		IF_COLOR_EQ  colorName, LIGHTBLUE_STR, lightBlue
		IF_COLOR_EQ  colorName, LIGHTGREEN_STR, lightGreen
		IF_COLOR_EQ  colorName, LIGHTCYAN_STR, lightCyan
		IF_COLOR_EQ  colorName, LIGHTRED_STR, lightRed
		IF_COLOR_EQ  colorName, LIGHTMAGENTA_STR, lightMagenta
		IF_COLOR_EQ  colorName, LIGHTGRAY_STR, lightGray
		
		; Set doesn't have color that user wrote ( Invalid Name)
		mWrite <"Warning: Wrong color name: Ignored color arguments in config.txt",0Dh,0Ah>
		mov  eax,4000 ;delay 1 sec
		call Delay
		mov eax, INVALID_HANDLE_VALUE
		ret

	ReadColorString ENDP
END