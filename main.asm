 INCLUDE Irvine32.inc
 include macros.inc
 INCLUDE Configuration.inc
.386
.model flat, stdcall
.stack 4096
 ExitProcess proto, dwExitCode:dword
 stringCat proto,
			destinationStr:				PTR BYTE,				; Pointer to concat new string destinationStr = sourceStr1 + sourceStr2
			sourceStr1:					PTR BYTE,				; First String1 (This string fill be first half)
			sourceStr2:					PTR BYTE,
			MAX_DESTIONATION_LENGTH:	DWORD					; Length of destination string

inputFileName proto						
checkForIndexFile proto
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
	
	; String that we print 
	inputFileNameMsg BYTE "Please input name of the text file: ", 0Dh, 0Ah, 0
	
	
	
	;*************************************************************************
	
	configFile BYTE "config.txt" , 0												; File that contains all settings for Text Editor
	indexFile  BYTE "index.txt"  , 0												; File that contains name of all txt files
	fullTxtFileName BYTE (MAX_FILE_NAME_LENGTH) DUP(?)								; full file name(Data_Path + name.txt) that user inputs, that we will open annd (DELETE,EDIT OR CREATE)
	fileName	BYTE (MAX_FILE_NAME_LENGTH  - MAX_PATH_LENGTH) DUP(0)				; string that user inputs
	cursorInfo CONSOLE_CURSOR_INFO <>												; Information about cursor
	 
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
	
	INVOKE checkForIndexFile

	cmp eax, INVALID_HANDLE_VALUE
	jz ExitProgram

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
			
			INVOKE inputFileName

			jmp menu
		
		editFile:
			
			INVOKE inputFileName
			jmp menu
			
		deleteFile:
			
			INVOKE inputFileName
			jmp menu
			
		listFiles:
			
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
; Registers changed: None
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


;**********************************************************************************
; Name: checkForIndexFile
;
; Procedure Checks if the working_directory contains the file "index.txt".
;
; Receives: 
;
; Returns: eax as flag (TRUE/FALSE)
;
; Registers changed: EDX (but is restored)
;**********************************************************************************
printMainPage endp

	checkForIndexFile PROC USES edx
		
		INVOKE stringCat, ADDR fullTxtFileName, ADDR settingsInfo.work_dir,  ADDR indexFile, MAX_FILE_NAME_LENGTH 
		mov edx, OFFSET fullTxtFileName
		call OpenInputFile
		
		cmp eax, INVALID_HANDLE_VALUE
		je Error_Msg
		call CloseFile

		ret

		Error_Msg:
		mWrite <"Error: There is no index.txt file in working directory",0Dh,0Ah>
		mov eax, INVALID_HANDLE_VALUE
		ret



	checkForIndexFile endp
;**********************************************************************************
; Name: stringCat
;
; Procedure Concats 2 strings into one 
;
; Receives: PTR to DestinatioString PTR to sourceStr1 & PTR to SourceStr2
;
; Returns: eax as status register if eax = 0 it means function failed
;
; Registers changed:  edx ebx eax edi
;**********************************************************************************
	stringCat PROC USES edx ebx eax edi,
    destinationStr: PTR BYTE,
    sourceStr1: PTR BYTE,
    sourceStr2: PTR BYTE,
    MAX_DEST_LENGTH: DWORD

    ;  length of first string 
    mov edx, sourceStr1
    call StrLength
    mov ebx, eax            ; ebx = length of first string
    mov ecx, eax            ; ecx = temp for total length

    ;  length of second string 
    mov edx, sourceStr2
    call StrLength
    add ecx, eax            ; total length

    cmp ecx, MAX_DEST_LENGTH
    jae tooLong

	; Copy first string (without null)
	mov esi, sourceStr1
	mov edi, destinationStr
	mov ecx, ebx
	rep movsb

	; Copy second string 
	mov esi, sourceStr2
	mov ecx, eax
	rep movsb

	; Add NULL terminator
	mov byte ptr [edi], 0
    ret

tooLong:
    mWrite <"Error: File name is to big (Path + fileName.txt!",0Dh,0Ah>
	mov eax, 0
    ret

stringCat ENDP
;**********************************************************************************
; Name: inputFileName
;
; Procedure Ask user to input file name through terminal, checks if the name length is not zero or not to big
;
; Receives: None
;
; Returns: None
;
; Registers changed: 
;**********************************************************************************
inputFileName proc USES eax edx
	call clrscr							; Clear Terminal
	invoke GetConsoleCursorInfo, stdOutHandle, addr cursorInfo       ; Reads current state of cursor
	mov  cursorInfo.bVisible, 1										 ; Sets cursor to be invisible 
	invoke SetConsoleCursorInfo, stdOutHandle, addr cursorInfo       ; Sets up new state of cursor
	mov edx, offset inputFileNameMsg       
	call WriteString
	readInput:
		mov edx, OFFSET fileName
		mov ecx, (MAX_FILE_NAME_LENGTH  - MAX_PATH_LENGTH)
		call ReadString        ; EAX = written Chars ( max wrote can be = maxLength)

		; empty?
		cmp eax, 0
		je warnEmpty

		; if the user entered more than the buffer can hold (the rest remains in the input buffer)
		; we can check this by comparing EAX with ECX

		cmp eax, ecx
		je warnTooLong

		jmp inputOK

	warnEmpty:
		mWrite <"Warning: empty input!",0Dh,0Ah>
		jmp readInput

	warnTooLong:
		mWrite <"Warning: input name too long!",0Dh,0Ah>
		; flush preostale karaktere iz tastature
	flushLoop:
		call ReadChar
		cmp al, 0Dh        ; Enter
		jne flushLoop
		jmp readInput

	inputOK:
		; EAX = broj karaktera u bufferu, buffer je null-terminated
		ret

inputFileName ENDP
end main