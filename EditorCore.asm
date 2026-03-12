INCLUDE Irvine32.inc
include macros.inc
INCLUDE EditorCore.inc

;******************Extern Variables************************
EXTRN cursorInfo: CONSOLE_CURSOR_INFO 												; Information about cursor
EXTRN stdInHandle : handle
EXTRN stdOutHandle : handle
EXTRN consoleInfo : CONSOLE_SCREEN_BUFFER_INFO


;*****************Macros********************
SetCursor MACRO coordVar:REQ
		LOCAL label1
		mov ax, cursorCoord.X   ; take X (word)
		mov dl, al              ; move lower byte to DL
		mov ax, cursorCoord.Y   ; take Y (word)
		; Update if there are new max y value
		cmp ax, MaxXYCord.Y
		jb label1
		mov MaxXyCord.Y,ax
		label1:
		mov dh, al              ; move lower byte to DH
		call Gotoxy
ENDM

WriteConsole PROTO :DWORD, :PTR BYTE, :DWORD, :PTR DWORD, :DWORD


ButtonPollingTime EQU 10					; 50 ms 
EditorLoop proto, fileName:	PTR BYTE
.data
	; Main variables for text editor
	textBuffer BYTE TEXT_BUFFER_SIZE DUP(0)  
	textLength DWORD 0
	cursorPos  DWORD 0 								; Cursor position inside the text
	fileHandle 	  DWORD ?
	cursorCoord COORD <0,0>
	
	MaxXYCord COORD <0,0>
	saveMsg		BYTE "Do you want to save file?(Y-Yes, N-No): " , 0
	crlfstrg BYTE 0Dh,0Ah,0
	numberCharsWritte DWORD 0

	fileOpenFlag	BYTE 0
.code 

	EditTxtFile proc USES edx ecx eax ebx,
			fileName:	PTR BYTE				; Pointer to full file Name (path + fileName.txt)
		; Initial edit work
		call clrscr							; Clear Terminal	
		; Open file and write data in buffer
		mov edx, fileName
		call OpenInputFile
		mov fileHandle,eax

		mov edx, OFFSET textBuffer
		mov ecx, TEXT_BUFFER_SIZE
		call ReadFromFile
		jc   show_error_message
		; Update variables
		mov textLength, eax		
		mov cursorPos, eax
		
		; close input file
		mov eax, fileHandle
		call CloseFile

		; Initialize terminal screen
		mov edx, OFFSET textBuffer
		INVOKE WriteConsole, stdOutHandle, ADDR textBuffer, textLength, ADDR numberCharsWritte, NULL
		;Get cursor positon
		INVOKE GetConsoleScreenBufferInfo, stdOutHandle, ADDR consoleInfo

		; Copy X
		mov ax, consoleInfo.dwCursorPosition.X
		mov cursorCoord.X, ax

		; Copy Y
		mov ax, consoleInfo.dwCursorPosition.Y
		mov cursorCoord.Y, ax
		add ax,2
		mov maxXYCord.Y,ax

		;Calculate cursor Max x coordinate
		
		invoke GetConsoleScreenBufferInfo, stdOutHandle, ADDR consoleInfo

		mov ax, consoleInfo.srWindow.Right
		sub ax, consoleInfo.srWindow.Left
		mov MaxXYCord.X,ax

		INVOKE EditorLoop, fileName
		; close output file
		ret
		show_error_message:
		mWrite <"Error: Failed edit Initialization: File exception thrown!",0Dh,0Ah>
		Call WriteWindowsMsg 
		
		ret
	EditTxtFile ENDP
	
	
;**********************************************************************************
; Name: EditorLoop
;
; Procedure Main loop in editor window, gets char from keyboard and do specific task (insert char, delete char or move cursor). After every change in text
;	buffer we must refresh terminal screen
;
; Receives: None
;
; Returns: None
;
; Registers changed:  eax
;**********************************************************************************
	
	EditorLoop PROC USES eax,
		fileName:	PTR BYTE				; Pointer to full file Name (path + fileName.txt)
mainLoop:
    mov  eax, ButtonPollingTime
    call Delay

    call ReadKey        ; EAX = info about key
    jz   mainLoop       ; wait for key event

    cmp al, 0
    je specialKey       ; if there are no ascii code it means that user inputed special key

    ; basic key
	cmp al, BACKSPACE_KEY         ; Backspace
    je backSpace
    cmp al, ESC_KEY         ; Escape
    je exitEditor
	cmp al, SAVE_KEY
	je saveFile
	
	
	call InsertChar
  
	call RenderScreen
    jmp mainLoop

specialKey:
    cmp ah, LEFT_KEY         ; left Arrow
    je moveLeft
    cmp ah, RIGHT_KEY         ; Right arrow
    je moveRight
   ; cmp ah, 48h         ; strelica gore
   ; je moveUp
   ; cmp ah, 50h         ; strelica dole
   ; je moveDown

    jmp mainLoop

moveLeft:
    call MoveCursorLeft
    jmp mainLoop

moveRight:
    call MoveCursorRight
    jmp mainLoop

backSpace:
    call DeleteChar
    call RenderScreen
    jmp mainLoop
saveFile:   
    mov dl, 0               ; kolona 0
    mov ax, MaxXyCord.Y
	mov dh,al
	inc dh
    call Gotoxy

    mov edx, OFFSET crlfstrg
	call WriteString

	mov edx, OFFSET saveMsg
	call WriteString

	
	Question:
		call ReadChar
		cmp al, 'y'
		je writeInFile
		cmp al,'n'
		jne  Question
	;Refresh screen
	call RenderScreen
	jmp mainLoop
	; Save File
	writeInFile:; Open .txt file to write
	invoke CreateFile,  filename, GENERIC_WRITE, FILE_SHARE_READ, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
	mov fileHandle, eax
    mov  edx,OFFSET textBuffer
    mov  ecx, textLength
    call WriteToFile
	mov fileOpenFlag, 1
	; Refresh screen
	call RenderScreen
	jmp mainLoop
exitEditor:
	mov al, fileOpenFlag
	.IF(al == 1)
		mov eax, fileHandle
		call CloseFile
		mov fileOpenFlag, 0
	.ENDIF
	call clearBuffer
    ret
EditorLoop ENDP
clearBuffer PROC USES eax ecx edi

    mov ecx, SIZEOF textBuffer   
    mov edi, OFFSET textBuffer   
    xor eax, eax                 

    rep stosb                    

    mov textLength, 0
    mov cursorPos, 0

    ret
clearBuffer ENDP
;**********************************************************************************
; Name: RenderScreen
;
; Procedure Updates terminal screen after there where changes made to text buffer
;
; Receives: None
;
; Returns: None	
;
; Registers changed:  None
;**********************************************************************************
	RenderScreen PROC USES edx eax
		call Clrscr
		mov edx, OFFSET textBuffer
		call WriteString
		SetCursor cursorCoord
		ret
	
	; OPTIMIZATION AKO BUDEM IMAO VREMENA SREDICU OVO DA BUDE BRZE
	; Calculate where is the position of
	;;	mov edx, OFFSET textBuffer
	;;	add edx, cursorPos
	;;	dec edx
	;;	call WriteString

	RenderScreen ENDP
;**********************************************************************************
; Name: DeleteChar
;
; Procedure Delete character at the position - 1 where points variable cursorPos, performs shifting of all elements after deleted char 
;
; Receives: None
;
; Returns: None	
;
; Registers changed:  ecx
;**********************************************************************************
	DeleteChar PROC USES eax ecx ebx edx

    cmp cursorPos, 0
    je endDelete

    ; Check if we are at the beggining of the text
    mov ecx, cursorPos
    dec ecx
    mov al, textBuffer[ecx]
    cmp al, 0Ah
    jne single_char_delete

    ; Check if the char left from the cursor is LF
    dec ecx
    mov al, textBuffer[ecx]
    cmp al, 0Dh
    jne single_char_delete

    ;  Delete CRLF pair
    sub cursorPos, 2
    mov ecx, cursorPos
    mov ebx, ecx
	add ebx, 2

	; Update max y coordinate
	mov dx, cursorCoord.Y   ; take Y (word)
	dec dx
	mov MaxXyCord.Y,dx

shift_crlf:
    mov al, textBuffer[ebx]
    mov textBuffer[ecx], al
    inc ecx
    inc ebx
    cmp al, 0
    jne shift_crlf
	; Update last char
	mov al, textBuffer[ebx]
    mov textBuffer[ecx], al
    
	sub textLength, 2

    ; Update terminal cursor
    dec cursorCoord.Y
    call lineLength
    mov cursorCoord.X, ax
    SetCursor cursorCoord
    jmp endDelete

single_char_delete:
    ;  Standard backspace 
    dec cursorPos
    mov ecx, cursorPos
	mov ebx, ecx
    inc ebx

shift_single:
    mov al, textBuffer[ebx]
    mov textBuffer[ecx], al
    inc ecx
    inc ebx
    cmp al, 0
    jne shift_single

    dec textLength

    ; Update terminal cursor
	mov ax, cursorCoord.X
	.IF(ax == 0)
		mov ax, maxXYCord.X
		mov cursorCoord.X,ax
		dec cursorCoord.Y
	.ELSE
		dec cursorCoord.X
	.ENDIF
    SetCursor cursorCoord

endDelete:
    ret
DeleteChar ENDP


;**********************************************************************************
; Name: InsertChar
;
; Procedure Insert character at the position where points variable cursorPos, performs shifting of all elements after inserted char 
;
; Receives: None
;
; Returns: None	
;
; Registers changed:  ecx
;**********************************************************************************
	InsertChar proc USES eax ebx ecx edx
	mov dl, al		; Save char that we want to insert
	mov ebx, cursorPos
		; Prevent overflow if buffer is full
		.IF textLength >= TEXT_BUFFER_SIZE-1
			ret
		.ENDIF
		; Check if we insert character at the end of the buffer
		.IF ebx == textLength
			mov  BYTE PTR textBuffer[ebx], al
			jmp update_cursor
		.ENDIF
		; Situation when we insert char in the midle of the text
		mov ecx, ebx
		mov bl,BYTE PTR textBuffer[ecx]				; Save char (in register) at the position where we insert new one		
		mov  BYTE PTR textBuffer[ecx], al 	; Insert new char
		inc ecx
		
		; Shift every character to right ( x[n+1] = x[n] )
		; Register al containts char that will be written in text (x[n]) and register bl contains char that will be replaced (x[n+1]) 
		.WHILE textBuffer[ecx] != 0
			mov al,bl					;
			mov bl,BYTE PTR textBuffer[ecx]				; Save char (in register) at the position where we insert new one		
			mov  BYTE PTR textBuffer[ecx], al 	; Insert new char
			inc ecx
		.ENDW 
		mov al,bl
		mov bl,BYTE PTR textBuffer [ecx]				; Save char (in register) at the position where we insert new one		
		mov  BYTE PTR textBuffer[ecx], al 	; Insert new char
		
		update_cursor:
		inc textLength
		inc cursorPos
		mov ax, cursorCoord.X
		

		.IF(dl == 0Ah || ax == maxXYCord.X)
			mov cursorCoord.X, 0
			mov ax, cursorCoord.Y
			inc ax
			mov cursorCoord.Y, ax
			; Update max y coordinate
			mov dx, cursorCoord.Y   ; take Y (word)
			inc dx
			mov MaxXyCord.Y,dx
		.ELSE
			; Ovo je bruteforce da zeznem bag , need to be updated
			mov bx, maxXYCord.X
			dec bx
			dec bx	; Make room for 2 char
			;************+ Main stuff
			mov ax, cursorCoord.X
			inc ax
			mov cursorCoord.X, ax
			;******************
			.IF(ax == bx)
				mov al, ENTER_KEY
				call insertChar	
			.ENDIF
			
			
		.ENDIF

		
			
		; If the user pressed enter we need to add 2 char instead of one 
		.IF (dl == ENTER_KEY)
			mov al, 0Ah
			call insertChar
		.ENDIF
		ret
	InsertChar ENDP
;**********************************************************************************
; Name: MoveCursorRight
;
; Procedure Moves cursor right (changes cursorPos and cursor coordinates
;
; Receives: None
;
; Returns: None	
;
; Registers changed:  eax ecx
;**********************************************************************************
	MoveCursorRight PROC USES eax ecx 
	mov eax, textLength
	cmp cursorPos, eax
	jae done
	mov ecx, cursorPos
	mov ah, BYTE PTR textBuffer[ecx]				; Save current character
	inc ecx
	mov al, BYTE PTR textBuffer[ecx]				; Save current character
	.IF (ah == 0Dh && al == 0Ah)					; Move to new line
		inc ecx
		.IF(BYTE PTR textBuffer[ecx] != 0)
			; Increment Y coordinat (vertical coordinate)
			mov ax, cursorCoord.Y
			inc ax
			mov cursorCoord.Y, ax
			; Set X coordinate to zero
			mov cursorCoord.X, 0
			; Update cursorPos (it should be incremented by 3)
			mov cursorPos, ecx
		.ENDIF
	.ELSE
		
		inc cursorPos
		; Increment X coordinat (vertical coordinate)
		mov ax, cursorCoord.X
		.IF(ax == maxXYCord.X)
			mov cursorCoord.X, 0
			inc cursorCoord.Y
		.ELSE
			inc ax
			mov cursorCoord.X, ax
		.ENDIF
	.ENDIF
	done:
	SetCursor cursorCoord
	ret
	MoveCursorRight ENDP
;**********************************************************************************
; Name: MoveCursorLeft
;
; Procedure Moves cursor left (changes cursorPos and cursor coordinates
;
; Receives: None
;
; Returns: None	
;
; Registers changed:  eax ebx ecx
;**********************************************************************************	
	MoveCursorLeft PROC USES eax ebx ecx

		cmp cursorPos, 0
		je done
		mov ecx, cursorPos

		mov ebx, ecx			; temp for cheking part
		mov ax, cursorCoord.X
		.IF (ax == 0) 
			;Check if the line break caused this or that text in previous line is to long to be shown in one terminal line
			dec ebx
			.IF(BYTE PTR textBuffer[ebx] == 0Dh || BYTE PTR textBuffer[ebx] == 0Ah )

				; Decrement Y coordinat (vertical coordinate)
				mov bx, cursorCoord.Y
				dec bx
				mov cursorCoord.Y, bx 
				; Here the cursor should be pointing to last char in previous row
			
				;  position cursorPos at the 0Dh char
			
				dec cursorPos
				dec cursorPos
				;		Pointer				- Pointer is used in lineLength
				; H E L L | O | 0Dh 0Ah
				;       cursorPos
				;
				call lineLength				; Calculate previous line length (without carriage return line feed chars) and that will be new X coordinate
				mov cursorCoord.X, ax
			.ELSE
				; Decrement Y coordinat (vertical coordinate)
				mov bx, cursorCoord.Y
				dec bx
				mov cursorCoord.Y, bx 
				mov bx, MaxXYCord.X
				mov cursorCoord.X, bx
				dec cursorPos
			.ENDIF
		.ELSE
			dec cursorPos
			; Decrement X coordinat (horizontal coordinate)
			dec ax
			mov cursorCoord.X, ax 
		.ENDIF
		done:
		SetCursor cursorCoord
		ret
		MoveCursorLeft ENDP

;**********************************************************************************
; Name: lineLength
;
; Procedure Calculates how many char there are in line
;
; Receives: None
;
; Returns: eax - Number of chars	
;
; Registers changed:  ebx edx ecx
;**********************************************************************************
	lineLength PROC USES ebx edx ecx
		
		mov ax,0							; Here we store length of the line
		mov ecx, cursorPos					; Cursor position points to 0Ah ( linefeed char)
		cmp ecx,0
		je finish					; EDGE case when OAh is also beggining of the text
		dec ecx
		find_newLine:
			cmp ecx,0
			je start_of_File
			mov bl, BYTE PTR textBuffer[ecx]	; Store char in register
			
			cmp bl, 0Ah							; Check if the char is linefeed
			je finish
			
			cmp bl, 0Dh							; Check if the char is carriage return
			je finish

			inc eax
			
			dec ecx
			jmp find_newLine
		start_of_File:
			inc eax
		finish:
			ret
		
	lineLength ENDP
END