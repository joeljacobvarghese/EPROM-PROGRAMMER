#make_bin#

#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#

#CS=0000h#
#IP=0000h#

#DS=0000h#
#ES=0000h#

#SS=0000h#
#SP=FFFEh#

#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#

	jmp start
	
	db 1021 dup(0)
	
start:
	sti
	;Initializing RAM
	mov	ax,0200h
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov sp,0FFEH

	; 8255 1: 20h-26h (Connected to seven-segment displays through ICs 14495)
    ;       upper byte of EPROM address     : port A    (Output)  
    ;       lower byte of EPROM address     : port B    (Output)
    ;       data to be programmed to EPROM  : port C    (Output)
    ;         
    ; 
    ; 8255 2: 30h-36h (Connected to the keypad, LEDs and data lines of EPROM)
    ;       data lines of EPROM to read from it : port A    (Input)
    ;       six rows of the keypad              : port B    (Input)
    ;               (PB6 and PB7 are connected to Vcc)
    ;       three columns of the keypad         : port Cl   (Output)
    ;               PC0-PC2:    Col0-Col2
    ;               PC3:        Connected to ground via resistor
    ;       three status LEDs                   : port Ch   (Output)
    ;               PC4:        LED1 - Not Empty        0001 xxxxb=1xh to be output
    ;               PC5:        LED2 - Fail             0010 xxxxb=2xh to be output
    ;               PC6:        LED3 - Prog completed   0100 xxxxb=4xh to be output
	;				PC7:        Grounded via resistor
    ;
    ;
    ; 8255 3: 40h-46h (Connected to the address lines, data lines, Vpp and CE' signals of the EPROM) 
    ;       data lines to the EPROM             : port A    (Output)
    ;       address lines of EPROM A0-7         : port B    (Output)
    ;       address lines of EPROM A8-11        : port Cl   (Output)
    ;       control signals of EPROM            : port Ch   (Output)
    ;               PC4:        Vpp to relay unit   
    ;               PC5:        CE' pin of EPROM via a NOT gate  
    ;               PC6:        Grounded via resistor
    ;               PC7:        Grounded via resistor

    ;Port A, B, Cl, Ch - O/P for 8255 20H
	mov al, 80h
	out 26h, al

    ;Port A, B, Ch - O/P , Port Cl - I/P for 8255 30H
	mov al, 92h
	out 36h, al

	;Port A, B, Cl, Ch - O/P for 8255 40h
	mov al, 80h
	out 46h, al

	;Initializing LEDs to OFF mode
	mov al, 00h
	out 34h, al
	
	;Checking all memory locations for ffh
	mov al, 20h			;0010 0000 for setting PC5
	out 44h, al

	mov bx, 0000h
check:
	mov al, bl
	out 42h, al
	mov al, bh
	and al, 0fh
	out 44h, al
	in al, 30h
	cmp al, 0ffh
	jz next
	mov al, 10h		
	out 24h, al			;Turn the LED labeled "Not Empty" on and exit
	jmp inf
next:
	inc bx
	cmp bx, 1000h
	jnz check
	
	mov al, 0Ah			;0000 101 0 for resetting PC5 using BSR mode (Enable pin for EPROM)
	out 46h, al

	;Creating table for 7 segment decoding values starting from 00
	mov si, 00h
	mov ax, 0EFEh
	mov [si], ax
	inc si
	inc si
	mov ax, 0DFEh
	mov [si], ax
	inc si
	inc si
	mov ax, 0BFEh
	mov [si], ax
	inc si
	inc si
	mov ax, 0EFDh		
	mov [si], ax
	inc si
	inc si
	mov ax, 0DFDh		
	mov [si], ax
	inc si
	inc si
	mov ax, 0BFDh		
	mov [si], ax
	inc si
	inc si
	mov ax, 0EFBh		
	mov [si], ax
	inc si
	inc si
	mov ax, 0DFBh		
	mov [si], ax
	inc si
	inc si
	mov ax, 0BFBh		
	mov [si], ax
	inc si
	inc si
	mov ax, 0EF7h		
	mov [si], ax
	inc si
	inc si
	mov ax, 0DF7h		
	mov [si], ax
	inc si
	inc si
	mov ax, 0BF7h		
	mov [si], ax
	inc si
	inc si
	mov ax, 0EEFh		
	mov [si], ax
	inc si
	inc si
	mov ax, 0DEFh		
	mov [si], ax
	inc si
	inc si
	mov ax, 0BEFh		
	mov [si], ax
	inc si
	inc si
	mov ax, 0EDFh		
	mov [si], ax
	inc si
	inc si
	mov ax, 0DDFh		
	mov [si], ax
	inc si
	inc si
	mov ax, 0BDFh		
	mov [si], ax
	;Table ends

	mov dx, 0000h			;Initialises address for EPROM to 0000h
	
	;DS:0150h will contain the data entered by the user

begin:
    mov al, 0ffh
    mov [150h], al  		;Initialise stored data to 0ffh
    
    call disp1				;displays the address to be programmed in EPROM and FF on seven-segment displays for data

	
	;Key press algorithm
	;initializing port c
    mov al, 00h
	out 34h, al

	;Check for key release
x1:	in al, 32h
	cmp al, 0ffh
	jnz x1

	;Delay for debounce
	call delay20

	;Detecting for key press
x2:	mov al, 00
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jz x2
	
    ;Debounce delay
	call delay20

	;Check if the key is still pressed
    mov al, 00
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jz x2
    
    ;Detect which key has been pressed
	;make col-0 low
	mov al, 0Eh			;1110b=8+4+2=0Eh
	mov ah, al			
	out 34h, al			
	in al, 32h          ;ah has input for columns, al has output from rows
	cmp al, 0ffh
	jnz hit

	;make col-1 low
	mov al, 0Dh			;1101b=8+4+1=0Dh
	mov ah, al
	out 34h, al
	in al, 32h          ;ah has input for columns, al has output from rows
	cmp al, 0ffh
	jnz hit

	;make col-2 low
	mov al, 0Bh			;1011b=8+2+1=0Bh
	mov ah, al  
	out 34h, al 
	in al, 32h          ;ah has input for columns, al has output from rows
	cmp al, 0ffh
	jnz hit

	jmp x1

hit:
	mov cx, 12h
	mov di, 00h
	mov si, 00h

x4:	mov bx, [di]            
	cmp ax, bx
	jz x5
	inc si
	inc di
	inc di
	loop x4

x5:
	mov ax, si 			;moving the digit to ax
	
    cmp al, 10h			;Backspace
	jz x2

	cmp al, 11h			;Enter
	jnz cont
	mov al, 40h
	out 34h, al
	jmp inf

cont:
	mov ax, si			;Any other key
	ror al, 4
	or al, 0fh
	mov [150h], al
	out 24h, al			;Display the received digit on seven segment display
	
	;Initialising columns for second key check
	mov al,00h
	out 34h,al

	;check for key release
y1:	in al, 32h
	cmp al, 0ffh
	jnz y1
	
    ;delay for debounce
	call delay20

	;detecting for second key press
y2:	mov al, 00h
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jz y2
	
    ;Debounce delay
	call delay20

    ;Check if the key is still pressed
	mov al, 00h
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jz y2

	;make col-0 low
	mov al, 0Eh			;1110b=0Eh
	mov ah, al
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jnz hit1

	;make col-1 low
	mov al, 0Dh			;1101b=0Dh
	mov ah, al
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jnz hit1

	;make col-2 low
	mov al, 0Bh			;1011b=0Bh
	mov ah,al
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jnz hit1

	jmp y1
hit1:
	mov cx, 12h		
	mov di, 00h
	mov si, 00h

y4:	mov bx,[di]
	cmp ax, bx
	jz y5
	inc di
	inc di
	inc si
	loop y4

y5: 
	mov ax, si ;moving the digit to ax
	
    cmp al, 10h			;Backspace->Display FF and take input from first key
	jnz y6
	mov al, 0ffh
	mov [150h], al
	out 24h, al ;displaying the digit
	jmp x1

y6:
	cmp al, 11h			;Enter key->press another key
	jz y1 

	mov bl, [150h]
	and bl, 0f0h
	or al, bl
	mov [150h], al 
	out 24h, al
	
	;Initialising columns for third key check
	mov al,00h
	out 34h,al

	;check for key release
z1:	in al, 32h
	cmp al, 0ffh
	jnz z1
	
    ;delay for debounce
	call delay20

	;detecting for second key press
z2:	mov al, 00h
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jz z2
	
    ;Debounce delay
	call delay20

	;Check if the key is still pressed
    mov al, 00h
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jz z2

	;make col-0 low
	mov al, 0Eh			;1110b=0Eh
	mov ah, al
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jnz hit2

	;make col-1 low
	mov al, 0Dh			;1101b=0Dh
	mov ah, al
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jnz hit2

	;make col-2 low
	mov al, 0Bh			;1011b=0Bh
	mov ah, al
	out 34h, al
	in al, 32h
	cmp al, 0ffh
	jnz hit2

	jmp z1

hit2:
	mov cx, 12h		
	mov di, 00h
	mov si, 00h

z4:	mov bx, [di]
	cmp ax, bx
	jz z5
	inc di
	inc di
	inc si
	loop z4

z5: 
	mov ax, si
	
    cmp al, 10h			;Backspace-> Display xF and retake input for second nibble
	jnz z6
	mov al, [150h]
	or al, 0fh
	mov [150h], al
	out 24h, al
	jmp y1

z6:
	cmp al, 11h			;Enter key-> Write to EPROM
	jz write

	jmp z1              ;Any other key is ignored

write:
	;output data and address to EPROM (initialize 40h 8255 to all O/P)
	mov al, [150h]
	out 40h, al         ;Make the data available on the data lines of EPROM

	mov ax, dx
	out 42h, al
	ror ax, 8
	out 44h, al         ;Make the address available on the address lines of EPROM
	call delay55        ;Delay to stabilise the address and data on their lines

	;program the EPROM by enabling CE' and Vpp
	and al, 0fh	
	or al, 30h 			;output 0011b to port C upper
	out 44h, al		
	call delay50	
	

	and al, 2fh	;reset Vpp
	out 44h, al

	;Reading from EPROM
	in al, 30h			
	mov ah, [150h]
	cmp ah, al
	jnz fail            ;If the input data and output data do not match, jump to 'fail' label and exit
	inc dx
	mov al, 0ffh
	mov [150h], al
	
	cmp dx, 1000
	jnz begin           ;If the entire EPROM has not been programmed, then repeat the procedure for the next address

	mov al, 40h		    ;To turn on the LED labeled Programming Completed and then exit
	out 34h, al
	jmp inf
	
fail: 
	mov al, 20H         
	out 34h, al         ;Turn on the LED labeled Programming failed
	jmp inf
	
inf:
    jmp inf


;produces 50ms delay
delay50 proc near
		mov cx, 0
		mov dx, 0C350h		;Hexadecimal corresponding to 50000 microseconds
		mov al, 0
		mov ah, 86h
		int 15h             ;The wait interrupt
delay50	endp

;produces 55ms delay
delay55 proc near
		mov cx, 0
		mov dx, 0D6D8h		;Hexadecimal corresponding to 55000 microseconds
		mov al, 0
		mov ah, 86h
		int 15h
delay55	endp

;produces 20ms delay
delay20 proc near
		mov cx,	0
		mov dx, 4E20h       ;Hexadecimal corresponding to 20000 microseconds
		mov al, 0
		mov ah, 86h
		int 15h         
delay20	endp


;disp1 displays DX on the address 7 segment displays and FF on the data displays
disp1 proc near
    mov ax, dx
	out 22h, al     ;display lower byte in Port B
    ror ax, 8 
    out 20h, al	    ;display upper byte in Port A
    mov al, 0ffh
    out 24h, al     ;display FF in port C
	ret
disp1 endp