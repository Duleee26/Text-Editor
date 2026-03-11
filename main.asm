INCLUDE Irvine32.inc
 include macros.inc
 INCLUDE Configuration.inc
 INCLUDE EditorCore.inc
 includelib kernel32.lib
.386
.model flat, stdcall
.stack 4096
 ExitProcess proto, dwExitCode:dword
 DeleteFileA PROTO :DWORD
 MoveFileA PROTO :DWORD, :DWORD
 stringCat proto,
			destinationStr:				PTR BYTE,				; Pointer to concat new string destinationStr = sourceStr1 + sourceStr2
			sourceStr1:					PTR BYTE,				; First String1 (This string fill be first half)
			sourceStr2:					PTR BYTE,
			MAX_DESTIONATION_LENGTH:	DWORD					; Length of destination string

inputFileName proto						
checkForIndexFile	proto
updateIndexFile		proto
removeFromIndex		proto
displayIndexFile	proto
foundInIndex		proto
SetConsoleScreenBufferSize PROTO :DWORD, :COORD
	
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
	tempIndexFile BYTE "temp.txt",0													; Temporary index file for when we are deleting file from index.txt
	fullTxtFileName BYTE (MAX_FILE_NAME_LENGTH) DUP(?)								; full file name(Data_Path + name.txt) that user inputs, that we will open annd (DELETE,EDIT OR CREATE)
	fileName	BYTE (MAX_FILE_NAME_LENGTH  - MAX_PATH_LENGTH) DUP(0)				; string that user inputs												
	newline       BYTE 0Dh,0Ah
	buffer          BYTE 512 DUP(0)
	fileWasEmpty DWORD 1															; for checking if index file was empty
	foundFlag BYTE 0																; for finding file name in index.txt
	
    ; Terminal widnows size
    windowRect SMALL_RECT <xmin,ymin,xmax,ymax>   ; xmin=0, ymin=0, xmax=79, ymax=24
    bufferSize COORD <xmax+1,ymax+1>            ; širina=80, visina=25
.data?
	; Variables that are needed to handle the data entered in the console, ie. interaction with the user (With this we just want to make cursor invisible -_- )
	stdOutHandle handle ?
	stdInHandle handle ?		; A variable to control input to the console
	indexHandle   DWORD ?
	bytesWritten  DWORD ?		; Pointer to a DWORD to receive the number of bytes written (for WriteFile PROC)
	bytesRead     DWORD ?
	readHandle    DWORD ?
	writeHandle   DWORD ?
	; Variables that are needed to handle the data entered in the console, ie. interaction with the user (With this we just want to make cursor invisible -_- )
	consoleInfo CONSOLE_SCREEN_BUFFER_INFO <>
	cursorInfo CONSOLE_CURSOR_INFO <>						; Information about cursor
	public cursorInfo
	public stdInHandle
	public stdOutHandle
	public consoleInfo
	
.code
	main proc
	
	invoke SetConsoleTitle, addr winTitle	
	
	invoke GetStdHandle, STD_OUTPUT_HANDLE							 ;// Postavlja handle za ispis podataka
    mov  stdOutHandle, eax							 ; Sets a handle to print data 

	
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
		invoke SetConsoleTitle, addr winTitle			; Set Console Title
		; Print Main Menu to Terminal
		call printMainPage
		
		welcomeLoop:                    ; Loop through menu until user inputs value between (1-4)
								    
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

			; vukica 3/8
			invoke foundInIndex
			invoke updateIndexFile
			invoke CreateFile, ADDR fileName, GENERIC_WRITE, 0, 0, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, 0
			invoke CloseHandle, eax

			invoke SetConsoleTitle, addr fileName			; Set Console Title
			INVOKE stringCat, ADDR fullTxtFileName, ADDR settingsInfo.work_dir,  ADDR fileName, MAX_FILE_NAME_LENGTH
			INVOKE EditTxtFile, addr fullTxtFileName		; Open Edit Screen
			jmp menu
		
		editFile:
			
			INVOKE inputFileName
			invoke foundInIndex
			mov al, foundFlag
			cmp al, 0
			je menu
			invoke SetConsoleTitle, addr fileName			; Set Console Title
			INVOKE stringCat, ADDR fullTxtFileName, ADDR settingsInfo.work_dir,  ADDR fileName, MAX_FILE_NAME_LENGTH
			INVOKE EditTxtFile, addr fullTxtFileName		; Open Edit Screen
			jmp menu
			
		deleteFile:
			
			INVOKE inputFileName
			; provera da li fajl postoji u radnom direktorijumu
			invoke CreateFile, ADDR fileName, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
			cmp eax, -1
			je done         ; fajl ne postoji -> povratak u meni
			; ako fajl postoji, oslobadjamo handle i brisemo fajl
			invoke CloseHandle, eax
			invoke DeleteFileA, ADDR fileName
			invoke removeFromIndex
			done:
				jmp menu
			
		listFiles:
			invoke displayIndexFile
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
		; dodatak koji se bavi ekstenzijom
		mov esi, OFFSET fileName
		add esi, eax          ; ESI = kraj stringa

		cmp eax, 4
		jb addTxt             ; ako je ime krace od 4 sigurno nema .txt

		mov edi, esi
		sub edi, 4            ; pokazuje na cetvrti karakter od kraja

		cmp BYTE PTR [edi], '.'
		jne addTxt
		cmp BYTE PTR [edi+1], 't'
		jne addTxt
		cmp BYTE PTR [edi+2], 'x'
		jne addTxt
		cmp BYTE PTR [edi+3], 't'
		jne addTxt

		jmp done              ; vec ima .txt

	addTxt:
		mov BYTE PTR [esi], '.'
		mov BYTE PTR [esi+1], 't'
		mov BYTE PTR [esi+2], 'x'
		mov BYTE PTR [esi+3], 't'
		mov BYTE PTR [esi+4], 0

	done:
		ret

inputFileName ENDP



;**********************************************************************************
; Name: updateIndexFile
;
; Procedure used for adding new file name at the end of index.txt file
;
; Receives: None
;
; Returns: None
;
; Registers changed: 
;**********************************************************************************
updateIndexFile PROC USES eax ecx edx esi
	cmp foundFlag, 1
	je fileAlreadyExists

    ; otvaranje index.txt
    invoke CreateFile, ADDR indexFile, GENERIC_WRITE, FILE_SHARE_READ, 0, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0

    mov indexHandle, eax

    ; pomeranje na kraj fajla
    invoke SetFilePointer,indexHandle, 0, 0, FILE_END
    ; izracunavanje duzine stringa fileName
    mov edx, OFFSET fileName
    call StrLength
    mov ecx, eax

    ; upis imena fajla
    invoke WriteFile, indexHandle, ADDR fileName, ecx, ADDR bytesWritten, 0

    ; upis novog reda
    invoke WriteFile, indexHandle, ADDR newline, 2, ADDR bytesWritten, 0

    ; zatvaranje fajla
    invoke CloseHandle, indexHandle
	jmp done

	fileAlreadyExists:
		call Clrscr
		call Crlf
		mWrite <"File already exists.", 0Dh, 0Ah>
		mWrite "Press any key to return to menu..."
		call ReadChar
	done:
		ret

updateIndexFile ENDP

;**********************************************************************************
; Name: displayIndexFile
;
; Procedure used for reading index.txt and writing all files on output
;
; Receives: None
;
; Returns: None
;
; Registers changed: 
;**********************************************************************************
displayIndexFile PROC USES eax ecx edx

    call Clrscr
    mov fileWasEmpty, 1

    ; otvaranje index.txt
    invoke CreateFile, ADDR indexFile, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
    mov indexHandle, eax

readLoop:

    invoke ReadFile, indexHandle, ADDR buffer, SIZEOF buffer - 1, ADDR bytesRead, 0

    cmp bytesRead, 0
    je checkEmpty

    mov fileWasEmpty, 0

    mov eax, bytesRead
    mov buffer[eax], 0

    mov edx, OFFSET buffer
    call WriteString

    jmp readLoop

checkEmpty:

    cmp fileWasEmpty, 1
    jne done

    mWrite <"No files in index.",0dh,0ah>

done:

    invoke CloseHandle, indexHandle

    call Crlf
    mWrite "Press any key to return to menu..."
    call ReadChar

    ret

displayIndexFile ENDP

;**********************************************************************************
; Name: removeFromIndex
;
; Procedure used for removing file name from index.txt (should be called when user wants to delete file)
;
; Receives: None
;
; Returns: None
;
; Registers changed: 
;**********************************************************************************
removeFromIndex PROC USES eax ecx edx esi edi
	invoke CreateFile, ADDR indexFile, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
	mov readHandle, eax
	invoke CreateFile, ADDR tempIndexFile, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
	mov writeHandle, eax
	readLoop:
		invoke ReadFile, readHandle, ADDR buffer, SIZEOF buffer, ADDR bytesRead, 0
		cmp bytesRead,0
		je finished

		mov esi, 0                ; start indeksa u bufferu
	nextLine:
		mov edi, esi
	findLF:
		cmp edi, bytesRead
		je doneLines              ; kraj bafera

		cmp buffer[edi], 0Ah      ; LF
		jne incEDI
		jmp foundLine
	incEDI:
		inc edi
		jmp findLF

	foundLine:
		mov byte ptr buffer[edi],0   ; LF -> 0
		cmp edi, esi
		je skipCR
		cmp buffer[edi-1], 0Dh       ; CR -> 0
		jne skipCR
		mov byte ptr buffer[edi-1],0
	skipCR:
		invoke Str_compare, ADDR buffer[esi], ADDR fileName
		je nextLineStart              ; preskoci ako jednako

		; upis linije
		lea edx, buffer[esi]
		call StrLength
		mov ecx, eax
		invoke WriteFile, writeHandle, ADDR buffer[esi], ecx, ADDR bytesWritten, 0
		invoke WriteFile, writeHandle, ADDR newline, 2, ADDR bytesWritten, 0

	nextLineStart:
		inc edi
		mov esi, edi
		cmp esi, bytesRead
		jl nextLine

	doneLines:
		jmp readLoop
	finished:
		invoke CloseHandle, readHandle
		invoke CloseHandle, writeHandle
		invoke DeleteFileA, ADDR indexFile
		invoke MoveFileA, ADDR tempIndexFile, ADDR indexFile
		ret
removeFromIndex ENDP

;**********************************************************************************
; Name: foundInIndex
;
; Procedure used for checking if file name is in index.txt. File name is at ADDR fileName
;
; Receives: None
;
; Returns: None
;
; Registers changed:
;**********************************************************************************
foundInIndex PROC USES eax ecx edx esi edi
    ; Otvori index.txt
    invoke CreateFile, ADDR indexFile, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
    mov readHandle, eax
    cmp readHandle, INVALID_HANDLE_VALUE
    je notFound       ; ako ne moze da otvori, flag = 0

    mov foundFlag, 0         ; podesi flag = 0
	readLoop:
		invoke ReadFile, readHandle, ADDR buffer, SIZEOF buffer, ADDR bytesRead, 0
		cmp bytesRead, 0
		je doneSearching  ; kraj fajla

		mov esi, 0        ; start indeksa u bufferu

	nextLine:
		mov edi, esi
	findLF:
		cmp edi, bytesRead
		je doneBuffer     ; kraj bafera, nastavi ReadFile
		cmp buffer[edi], 0Ah
		jne incEDI
		jmp foundLine
	incEDI:
		inc edi
		jmp findLF

	foundLine:
		mov byte ptr buffer[edi], 0      ; LF -> 0
		cmp edi, esi
		je skipCR
		cmp buffer[edi-1], 0Dh           ; CR -> 0
		jne skipCR
		mov byte ptr buffer[edi-1], 0
	skipCR:
		lea edx, buffer[esi]             ; adresa linije
		invoke Str_compare, edx, ADDR fileName
		je fileFound                      ; ako jednako, flag = 1

		inc edi
		mov esi, edi
		cmp esi, bytesRead
		jl nextLine
	doneBuffer:
		jmp readLoop

	fileFound:
		mov foundFlag, 1                         ; flag = 1
		jmp doneSearching

	notFound:
		mov foundFlag, 0

	doneSearching:
		invoke CloseHandle, readHandle
		ret
foundInIndex ENDP

end main