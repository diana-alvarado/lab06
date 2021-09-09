; Archivo: labs.S
; Dispositivo: PIC16F887
; Autor: Diana Alvarado
; Compilador: pic-as (v2.30), MPLABX V5.40
;
; Programa: Contador de 8 bits 
; Hardware: LEDs en el puerto A, push pull down en RB0 y RB1
;
; Creado: 19 ago, 2021
; Última modificación: 19 ag, 2021
; PIC16F887 Configuration Bit Setting
; Assembly source line config statements
PROCESSOR 16F887
 #include <xc.inc>
 
 ;configuration word 1
  CONFIG FOSC=INTRC_NOCLKOUT	// Oscillador Interno sin salidas, XT
  CONFIG WDTE=OFF   // WDT disabled (reinicio repetitivo del pic)
  CONFIG PWRTE=OFF   // PWRT enabled  (espera de 72ms al iniciar)
  CONFIG MCLRE=OFF  // El pin de MCLR se utiliza como I/O
  CONFIG CP=OFF	    // Sin protección de código
  CONFIG CPD=OFF    // Sin protección de datos
  
  CONFIG BOREN=OFF  // Sin reinicio cuándo el voltaje de alimentación baja de 4V
  CONFIG IESO=OFF   // Reinicio sin cambio de reloj de interno a externo
  CONFIG FCMEN=OFF  // Cambio de reloj externo a interno en caso de fallo
  CONFIG LVP=OFF     // programación en bajo voltaje
 
 ;configuration word 2
  CONFIG WRT=OFF    // Protección de autoescritura por el programa desactivada
  CONFIG BOR4V=BOR40V // Reinicio abajo de 4V, (BOR21V=2.1V)

   ;----------------------------- macros -------------------------------
  wdivl	macro divisor  
    movwf var2    
    clrf var2+1  
	
    incf var2+1   ; Las veces que ha restado
    movlw divisor  

    subwf var2, f   ;se resta con el divisor y se guarda en F
    btfsc CARRY    ;revisa si existe acarreo
    goto $-4	; si no hay acarreo, la resta se repite
	
    decf var2+1,W    ; se guardan los resultados en W
    movwf cociente   
    
    movlw divisor	    
    addwf var2, W
    movwf residuo
	
    endm
  
 
  reinicio_tmr0 macro
    banksel PORTA
    movlw   220	    ;Tiempo deseado =4*tiempo de oscilación *(256-N)*(PRESCALER)
    movwf   TMR0    
    bcf	    T0IF    
    endm

 reinicio_tmr1  macro
   movlw   0x83		
   movwf   TMR1H
   movlw   0x09
   movwf   TMR1L
   bcf	    TMR1IF 
  endm

 ;-------------------------------- variables ---------------------------------
 PSECT	udata_bank0
    cont: DS 2    ; 2 byte
    cont1: DS 2 
    cont2: DS 2 
    segundos: DS 2
    micro: DS 2
    bandera: DS 1
    display_var: DS 3
    cociente: DS 1
    residuo:DS 1
    decenas:DS 1
    unidads:DS 2
    var2:DS 2
    var3:DS 2
    contador: DS 1
    
    
  PSECT	udata_shr   ;common memory
    W_TEMP:  DS 1   ; 1 byte
    STATUS_TEMP: DS 1	    ; 1 byte
    
    
 ;----------------------------- vector reset -------------------------------; 
 PSECT resVect, class=CODE, abs, delta=2 
 ORG 00h          ;posición en 0
    
 resetVec:        ;regresar a la posicion 0 
  PAGESEL main	 
  goto main     
 
    
;------------------------- vector interrupcion ----------------------------;

PSECT intVect, class=CODE, abs, delta=2  
ORG 04h          ;posicion en 0004h 

push:
    movwf W_TEMP	
    swapf STATUS, W   
    movwf STATUS_TEMP 
    
isr:    
    btfsc T0IF 
    call  int_t0	 
    btfsc TMR1IF
    call int_t1
    btfsc TMR2IF
    call int_t2
    
pop:
    swapf STATUS_TEMP, W  
    movwf STATUS	    
    swapf W_TEMP, F	    
    swapf W_TEMP, W	    
    retfie    
 ;--------------------- sub rutina de interrpcion ----------------------------
 int_t0:
    reinicio_tmr0	    ;50 ms
    clrf    PORTD     
    btfss   bandera, 0 
    goto    display_0
    
    btfss   bandera, 1
    goto    display_1
    return

   
display_0:
    bsf	    bandera,	0
    movf    display_var, W
    movwf   PORTA
    bsf	    PORTD,0
    return
    

display_1:
    bsf	    bandera,	1
    movf    display_var+1, W
    movwf   PORTA
    bsf	    PORTD,  1
    clrf    bandera
    return
    
    
 int_t1:
    reinicio_tmr1
    incf segundos
    movf segundos, W
    sublw 10
    btfsc ZERO
    goto reinicio_t0
    incf PORTB
    
 int_t2:
    clrf    TMR2
    bsf	    TMR2IF
    incf    micro
    movf    micro, W
    sublw   10
    btfss   ZERO
    goto    reinicio_t0
    clrf    micro
    btfsc   PORTC, 0
    goto    apagar
    bsf	    PORTC, 0
    return
    
 apagar:
    bcf	    PORTC, 0
    return
    
 reinicio_t0:
    return
 
 PSECT code, delta=2, abs 
 ORG 100h	 ;posicion del codigo 100
 
 ;------------------------------- tabla ---------------------------------- 
 tabla:
    clrf    PCLATH
    bsf	    PCLATH, 0	;PCLATH =01    PCL=02
    andlw   0x0f
    addwf   PCL		;PC = PCLATH + PCL + W
    retlw   00111111B	;0
    retlw   00000110B	;1
    retlw   01011011B	;2
    retlw   01001111B	;3
    retlw   01100110B	;4
    retlw   01101101B	;5
    retlw   01111101B	;6
    retlw   00000111B	;7 
    retlw   01111111B	;8
    retlw   01101111B	;9
    retlw   01110111B	;A
    retlw   01111100B   ;B
    retlw   00111001B	;C
    retlw   01011110B	;D
    retlw   01111001B	;E
    retlw   01110001B	;F
    
;------------------------ configuracion ---------------------------------
 main:
    call    config_io
    call    config_reloj
    call    config_tmr0
    call    config_int_enable
    call    config_tmr1
    call    config_tmr2
    banksel PORTA
    
 ;---------------------------  LOOP PRINCIPAL -------------------------------- 

 loop:
    call decena
    call preparar_displays
    goto loop	; loop forever

 ;------------------- SUB RUTINAS --------------------------------------------

 config_io:
    banksel ANSEL	;banco 11
    clrf    ANSEL ;pines digitales
    clrf    ANSELH
    
    banksel TRISA	;banco 01
    clrf   TRISA ; port A como salida
    clrf TRISD ; port D como salida
    clrf TRISC ; port C como salida
    clrf TRISB ; port B como salida
    clrf TRISE ;PORT E como salida


   ; bsf TRISB, UP ;RB6 como entrada
    ;bsf TRISB, DOWN ;RB7 como entrada
       
    ;bcf OPTION_REG, 7 ;Habilitar pull ups
    ;bsf WPUB, UP ;push up UP
    ;bsf WPUB, DOWN ;push up DOWN
 
    banksel PORTA	;banco 00
    clrf PORTA
    clrf PORTB
    clrf PORTC
    clrf PORTD
    clrf PORTE
    return
    
    
  config_reloj: ;configurar el oscilador
    banksel OSCCON  ;se configura a 2 MHz =101    
    bsf IRCF2	    ; OSCCON, 6
    bcf IRCF1	    ; OSCCON, 5
    bcf IRCF0	    ; OSCCON, 4
    bsf SCS	    ; reloj interno
    return
    
 config_tmr0: 
    banksel TRISA   ; 50 ms
    bcf T0CS    ;colocar el reloj interno
    bcf	PSA	    ;assignar el prescaler para el modulo timer0
    bsf	PS2
    bsf	PS1
    bsf	PS0	    ;PS = 111, prescalrer = 1:256 
    reinicio_tmr0
    return 
 
 config_tmr1:
    banksel PORTA	;2Hz
    bcf TMR1GE	; siempre contando
    bsf T1CKPS0	; prescale2 1:8
    bsf T1CKPS1
    bcf T1OSCEN	;reloj interno
    bcf TMR1CS
    bsf TMR1ON	;prender timer 1
    reinicio_tmr1  
    return
  
  config_tmr2:
    banksel PORTA	;20Hz
    bsf	 TOUTPS3	; prescaler 1:16
    bsf	TOUTPS2
    bsf	TOUTPS1
    bsf	TOUTPS0
    
    bsf	TMR2ON
    
    bsf	T2CKPS1	; prescaler 1:16
    bsf	T2CKPS0
    
    banksel TRISB
    movwf   196
    movwf   PR2
    bcf	    TMR2IF
    return
    
  config_int_enable:
    banksel TRISA
    bsf	TMR1IE	; interrupcion tmr1
    bsf	TMR2IE	; interrupcion tmr2
    banksel PORTA
    bcf	T0IF	; bandera tmr0
    bcf	TMR1IF	; bandera tmr1
    bcf	TMR2IF
    
    bsf	T0IE	; habilitar interrupcion tmr0
    bsf	PEIE	;interrupciones perifericas
    bsf	GIE		;HABILITA interrupciones globales
       
    return
   
 preparar_displays: 
    movf    decenas, W
    call    tabla
    movwf   display_var
    
    movf    unidads, W
    call    tabla
    movwf   display_var+1
    return
 
  decena:    ;decenas 
    movf    segundos, W
    wdivl   10
    movf    cociente, W
    movwf    decenas
    movf    residuo, W
    
  unidades:
    movwf   unidads
    return    
 END


