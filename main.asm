 INCLUDE Irvine32.inc
 include macros.inc
 INCLUDE Configuration.inc
.386
.model flat, stdcall
.stack 4096
 ExitProcess proto, dwExitCode:dword

.data
;******************* Extern Variables********************
EXTRN settingsInfo:configurationParameters_t



.data
	;********************* Main Menu Window **********************************
	MainPage1 	BYTE "_____         _     _____    _ _ _             ", 0Dh, 0Ah, 0 
	MainPage2	BYTE "|_   _|       | |   |  ___|  | (_) |            ", 0Dh, 0Ah, 0 
	MainPage3	BYTE "  | | _____  _| |_  | |__  __| |_| |_ ___  _ __ ", 0Dh, 0Ah, 0 
	MainPage4	BYTE "  | |/ _ \ \/ / __| |  __|/ _` | | __/ _ \| '__|", 0Dh, 0Ah, 0
	MainPage5	BYTE "  | |  __/>  <| |_  | |__| (_| | | || (_) | |   ", 0Dh, 0Ah, 0
	MainPage6	BYTE "  \_/\___/_/\_\\__| \____/\__,_|_|\__\___/|_|   ", 0Dh, 0Ah, 0
	MainPage7	BYTE "                                               ", 0Dh, 0Ah, 0
	
	welcomeString BYTE  " ", 0Dh, 0Ah,
                  "1. Create a new text file", 0Dh, 0Ah,
                  "2. Edit an existing file", 0Dh, 0Ah,
                  "3. Delete an existing file", 0Dh, 0Ah,
                  "4. List available files", 0Dh, 0Ah, 0
				  
	winTitle byte "Text Editor", 0						; Terminal Title
	
	;*************************************************************************
	
	configFile BYTE "config.txt" , 0					; File that contains all settings for Text Editor
	
	cursorInfo CONSOLE_CURSOR_INFO <>					; Information about cursor
	
.data?
	; Variables that are needed to handle the data entered in the console, ie. interaction with the user (With this we just want to make cursor invisible -_- )
	stdOutHandle handle ?
	stdInHandle handle ?		; A variable to control input to the console
	
.code
	main proc
	
	invoke SetConsoleTitle, addr winTitle	
	invoke GetStdHandle, STD_OUTPUT_HANDLE							 ; Sets a handle to print data 
	mov  stdOutHandle, eax

	; Set up Text Editor based on config.txt (Backround & Letter Color and Working Directory)
	INVOKE InitializeSettings  , addr configFile
	cmp eax, INVALID_HANDLE_VALUE
	jz ExitProgram

	INVOKE AplySettings
	
	menu:
		call clrscr							; Clear Terminal
		
		invoke GetConsoleCursorInfo, stdOutHandle, addr cursorInfo       ; Reads current state of cursor
		mov  cursorInfo.bVisible, 0										 ; Sets cursor to be invisible 
		invoke SetConsoleCursorInfo, stdOutHandle, addr cursorInfo       ; Sets up new state of cursor
		; Print Main Menu to Terminal
		call printMainPage
		
		welcomeLoop:                    ; Loop through menu unitl user inputs value between (1-4)
								    
		call ReadChar

		cmp al, '1'                 ; 1. Create File
		je createTextFile

		cmp al, '2'                 ; 2. Edit File
		je editFile

		cmp al, '3'                 ; 3. Delete File
		je deleteFile

		cmp al, '4'                 ; 4. List all Files
		je listFiles
		jne welcomeLoop             ; Loop back (infinite loop)
		
		createTextFile:
			mov eax,1
			call writeDec
			jmp menu
		
		editFile:
			mov eax,2
			call writeDec
			jmp menu
			
		deleteFile:
			mov eax,3
			call writeDec
			jmp menu
			
		listFiles:
			mov eax,4
			call writeDec
			jmp menu

	ExitProgram:
		nop
	invoke ExitProcess, 0
	main endp
	
;**********************************************************************************
; Name: printMainPage
;
; Procedure prints Main Menu to the Terminal
;
; Receives: None
;
; Returns: None
;
; Registers changed: EDX (but is restored)
;**********************************************************************************
	printMainPage PROC

	;save registers
	push edx
	mov edx, offset MainPage1       
	call WriteString
	mov edx, offset MainPage2       
	call WriteString
	mov edx, offset MainPage3       
	call WriteString
	mov edx, offset MainPage4       
	call WriteString
	mov edx, offset MainPage5       
	call WriteString
	mov edx, offset MainPage6       
	call WriteString
	mov edx, offset MainPage7       
	call WriteString
	mov edx, offset welcomeString       
	call WriteString
	
	pop edx
	
	ret	
printMainPage endp

end main