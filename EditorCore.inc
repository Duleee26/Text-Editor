.386
.model flat, stdcall
;************************************************************
; EditorCore.inc
;
; This module contains core functionality for the console
; text editor, including keyboard input handling, cursor
; movement, screen refreshing, and basic text editing logic.
;************************************************************

	;// Definisanje velicine prozora 
	xmin = 0	;// leva ivica
	xmax = 79	;// desna ivica
	ymin = 0	;// gornja ivica
	ymax = 24	;// donja ivica

; Keyboard ASCII values for arrow keys & ESC
	LEFT_KEY = 4Bh        
	UP_KEY = 026h
	RIGHT_KEY = 4Dh
	DOWN_KEY = 028h
	ESC_KEY = 01Bh
	BACKSPACE_KEY = 08h
	ENTER_KEY = 0Dh
	SAVE_KEY = 1Ah

;
	TEXT_BUFFER_SIZE EQU 65536  ; Max size that we can store is 64 KB text
;**********************************************************************************
; Name: EditTxtFile
;
; Procedure Edits txt file, and prints current state of the file (buffer) to terminal 
;
; Receives: PTR to DestinatioString PTR to sourceStr1 & PTR to SourceStr2
;
; Returns: eax as status register if eax = 0 it means function failed
;
; Registers changed:  edx ebx eax edi
;**********************************************************************************

	EditTxtFile PROTO,
			fileName:	PTR BYTE				; Pointer to full file Name (path + fileName.txt)