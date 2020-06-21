    list P=16F689

#include p16f689.inc

#define ENABLE_GLOBAL_INTERRUPTS  bsf INTCON, GIE
#define DISABLE_GLOBAL_INTERRUPTS bcf INTCON, GIE

#define TEMP_40_LR d'162'
#define TEMP_40_HR d'166'

#define TEMP_55_LR d'143'
#define TEMP_55_HR d'147'

#define TEMP_65_LR d'130'
#define TEMP_65_HR d'134'

#define TEMP_80_LR d'119'
#define TEMP_80_HR d'123'

#define TEMP_90_LR d'107'
#define TEMP_90_HR d'111'

#define TEMP_100_LR d'89'
#define TEMP_100_HR d'93'

rTon         EQU 0x20
rToff        EQU 0x21
dlymscnt     EQU 0x22
dlymsps      EQU 0x23
dlyscnt      EQU 0x24
dlysps       EQU 0x25
adcresult    EQU 0x26

move_literal macro reg, imm
    movlw imm
    movwf reg
    endm

move_register macro dst, src
    movf src, 0
    movwf dst
    endm

bankswitch macro bank
    if bank == 0
        bcf STATUS, RP0
        bcf STATUS, RP1
    else
    if bank == 1
        bsf STATUS, RP0
        bcf STATUS, RP1
    else
    if bank == 2
        bcf STATUS, RP0
        bsf STATUS, RP1
    else
    if bank == 3
        bsf STATUS, RP0
        bsf STATUS, RP1
    endif
    endm

    ;__CONFIG _INTOSC & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _CPD_OFF
    __CONFIG _HS_OSC & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _CPD_OFF

    org 0

    clrf FSR
    nop
    nop
    goto startup

; -- Interrupt Service Routine
ISR
    ; If Timer0 Interrupt Flag is set, skips goto and executes ISR
    ; btfss INTCON, 2
    ; goto return_from_interrupt

    ; Save content of register W
    movwf 0x70

    btfsc PORTC, RC0
    goto time_off
time_on
    nop
    nop
    bsf TRISC, TRISC0
    movf rTon, 0
    goto ret
time_off
    bcf PORTC, RC0
    bcf TRISC, TRISC0
    movf rToff, 0
    nop
    nop
ret
    movwf TMR0
    ; Clear Timer0 Interrupt Flag
    bcf INTCON, T0IF

    ; Restore content of register W
    movf 0x70, 0

    retfie
; -- end of Interrupt Service Routine

    org 0x50

; -- Subroutine delay_ms
delay_ms
    move_literal dlymsps, 0x04
set_dlymscnt
    move_literal dlymscnt, 0xE1
dec_dlymscnt
    nop
    nop
    decfsz dlymscnt, 1
    goto dec_dlymscnt
    decfsz dlymsps, 1
    goto set_dlymscnt
    return
; --
; -- Subroutine delay_s
delay_s
    move_literal dlysps, 0x04
set_dlyscnt
    move_literal dlyscnt, 0xEF
dec_dlyscnt
    call delay_ms
    decfsz dlyscnt, 1
    goto dec_dlyscnt
    decfsz dlysps, 1
    goto set_dlyscnt
    return
; --

startup
    ; Switch to bank 1
    bankswitch 1
    ; Oscillator configuration
    movlw 0x70
    iorwf OSCCON, 1
peripheral_init
    ; Port C direction (RC7 as input, others as outputs)
    move_literal TRISC, 0x80
    ; Port B direction (RB7 as output, for the rs232)
    ;bcf TRISB, TRISB7

    ; Timer0 Configuration
    move_literal OPTION_REG, 0xD1

    ; Partial ADC Configuration
    move_literal ADCON1, 0x60

    ; Switch to bank 2
    bankswitch 2
    ; Selects all PORTC as digital inputs/outputs except RC7/AN9
    clrf ANSEL
    clrf ANSELH
    bsf ANSELH, ANS9
    clrf PORTC

    ; Switch to bank 0, we're going to work there
    bankswitch 0

    ; Completing ADC Configuration
    move_literal ADCON0, 0x25

    ;bsf TXSTA, BRGH
    ;bsf TXSTA, TXEN
    ;bsf RCSTA, SPEN
    ;movlw d'64'
    ;movwf SPBRG

    ENABLE_GLOBAL_INTERRUPTS
    ; Timer0 Interrupt Enable
    bsf INTCON, T0IE

mainloop
    bsf ADCON0, GO
adc_not_done
    btfsc ADCON0, GO
    goto adc_not_done

    movf ADRESH, 0
    movwf adcresult
    sublw TEMP_40_LR
    btfsc STATUS, C
    goto check_55

    movf adcresult, 0
    sublw TEMP_40_HR
    btfsc STATUS, C
    goto pwm_duty_40

check_55
    movf adcresult, 0
    sublw TEMP_55_LR
    btfsc STATUS, C
    goto check_65

    movf adcresult, 0
    sublw TEMP_55_HR
    btfsc STATUS, C
    goto pwm_duty_55

check_65
    movf adcresult, 0
    sublw TEMP_65_LR
    btfsc STATUS, C
    goto check_80

    movf adcresult, 0
    sublw TEMP_65_HR
    btfsc STATUS, C
    goto pwm_duty_65

check_80
    movf adcresult, 0
    sublw TEMP_80_LR
    btfsc STATUS, C
    goto check_90

    movf adcresult, 0
    sublw TEMP_80_HR
    btfsc STATUS, C
    goto pwm_duty_80

check_90
    movf adcresult, 0
    sublw TEMP_90_LR
    btfsc STATUS, C
    goto check_100

    movf adcresult, 0
    sublw TEMP_90_HR
    btfsc STATUS, C
    goto pwm_duty_90

check_100
    movf adcresult, 0
    sublw TEMP_100_LR
    btfsc STATUS, C
    goto check_fullscale

    movf adcresult, 0
    sublw TEMP_100_HR
    btfsc STATUS, C
    goto pwm_duty_100

check_fullscale
    movf adcresult, 0
    sublw d'253'
    btfss STATUS, C
    goto pwm_duty_100

    ; No match: do nothing
    goto outernoint

pwm_duty_40
    move_literal rTon, d'238'
    move_literal rToff, d'230'
    goto outer
pwm_duty_55
    move_literal rTon, d'233'
    move_literal rToff, d'236'
    goto outer
pwm_duty_65
    move_literal rTon, d'228'
    move_literal rToff, d'241'
    goto outer
pwm_duty_80
    move_literal rTon, d'219'
    move_literal rToff, d'249'
    goto outer
pwm_duty_90
    move_literal rTon, d'214'
    move_literal rToff, d'255'
    goto outer
pwm_duty_100
    DISABLE_GLOBAL_INTERRUPTS
    bsf PORTC, RC1
    bsf TRISC, TRISC0
    goto outernoint
outer
    bcf PORTC, RC1
    ENABLE_GLOBAL_INTERRUPTS
outernoint

    ;movf PORTC
    ;xorlw b'00000010'
    ;movwf PORTC

    call delay_ms

    goto mainloop

    end
