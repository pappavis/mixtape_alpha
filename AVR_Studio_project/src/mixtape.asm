.include "m328pdef.inc" ; definitions file

; fuse settings
;
; internal 8MHz RC oscillator, slowest startup time
; isp enabled
; brownout disabled
; no boot reset
; no memory locks

; pin usage
;
; pb0:5 = led1:6, led7:11
; pb6   = led direction, 1 = led1:6, 0 = led7:11
; pb7   = nc
; pc0:5 = pad1:6, pad7:12
; pc6   = reset
; pd0   = pad1:6 control, 0 = active, 1 = off
; pd1   = pad7:12 control, 0 = active, 1 = off
; pd2   = power switch, 0 = on, 1 = off, int0
; pd3   = slider control, 1 = on, 0 = off
; pd4   = shift pad
; pd5,7 = shorted to ground, always set to input, pullups off
; pd6   = pwm out, oc0a, t0
; adc6  = slider analog input
; adc7  = nc
; aref  = cap, internal vcc

; hardware
;
; led1:6 correspond to pad1:6, and are on the wheel
; led7:11 correspons to pad7:12, and are the voice/rec/erase - erase does not have an led

; register usage
;
; r0  = multiply result lsb - do not use in main (not backed up)
; r1  = multiply result msb - do not use in main (not backed up)
; r2  = voice 1 pointer lsb
; r3  = voice 1 pointer msb
; r4  = voice 2 pointer lsb
; r5  = voice 2 pointer msb
; r6  = voice 3 pointer lsb
; r7  = voice 3 pointer msb
; r8  = voice 4 pointer lsb
; r9  = voice 4 pointer msb - do not touch these anywhere but t0
; r10 = null register
; r11 = led scan position - only for t2
; r12 = led1:6 state register (inverted logic - b7:6 always set) - write only, except t2
; r13 = led7:11 state register - write only, except t2
; r14 = voice 5 pointer lsb
; r15 = voice 5 pointer msb - do not touch these anywhere but t0
; r16 = main general swap register - main only
; r17 = main general swap register - main only
; r18 = t0 storage register - t0 only
; r19 = interrupt swap register - interrupts only
; r20 = tone 1 rate
; r21 = tone 2 rate
; r22 = tone 3 rate
; r23 = tone 4 rate
; r24 = tone 5 rate - write only, except t0
; r25 = main general swap register -  main only
; r26 = delay table pointer lsb
; r27 = delay table pointer msb - t0 only
; r28 = sequencer pointer lsb
; r29 = sequencer pointer msb - main only
; r30 = lookup table address lsb
; r31 = lookup table address msb - backed up in interrupts
; gpior0 = sreg storage during t0 interrupt - t0 only
; gpior1 = pad2 effect/rec/erase state - read only, except main
; gpior2 = pad2 voice state - read only, except main
; eedr = current note voice - read only, except main
; eearl = lfo value register - read only, except t2


; sram usage
;
; $0100 - $01ff = pattern memory
; $0200 - $07ff = delay memory
; $0800 - $08ef = variable storage
; $08f0 - $08ff = stack

.include "mixtape_defs.inc" ; definitions file with sram usage


; pattern storage format
;
; byte0 = time till next note
; byte1 = note voice
; byte2 = note frequency
; byte3 = led pattern

.org $0000
rjmp init ; initialization
.org INT0addr
jmp wakeup ; on/off switch handler
.org OC2Aaddr
rjmp t2int_led ; led handler
.org OC2Baddr
rjmp t2int_led ; led handler
.org OVF2addr
rjmp t2int_lfo ; fm/am vco handler
.org OVF1addr
rjmp t1int ; main loop timer - not used, checked in main loop
.org OVF0addr
rjmp t0int ; sample playback handler

init: ; stuff done only on reset

ldi r16,$00
out gpior1,r16 ; set effect/rec state to off
sts pattern_top_lsb,r16
ldi r16,$01
sts pattern_top_msb,r16  ; set pattern point to start - empty pattern

start: ; initialize all the stuffs

cli ; in case interrupts are on
ldi r16,$00
out smcr,r16 ; clear the sleep mode register to be on the safe side

;move stack point to end of sram (for now, will put it elsewhere later)
ldi r16,high(ramend)
out sph,r16
ldi r16,low(ramend)
out spl,r16

;initialize ports
ldi r16,$80
out portb,r16 ; set all of portb to 0, except unused pin
ldi r16,$7f
out ddrb,r16 ; set portb to output, except unused pin
ldi r16,$40
out portc,r16 ; turn off pullups for portc, except reset pin
ldi r16,$00
out ddrc,r16 ; set all of portc to input
ldi r16,(0<<pd7)|(0<<pd6)|(0<<pd5)|(1<<pd4)|(1<<pd3)|(1<<pd2)|(1<<pd1)|(1<<pd0)
out portd,r16 ; pullups on for pd2,4 high for pd0,1,4, low for all else
ldi r16,$4b
out ddrd,r16 ; pd0,1,3,6 output, rest input

;setup power reduction registers
ldi r16,$86
sts prr,r16 ; turn off twi,usart,spi

;setup t0 for pwm (31.25khz)
ldi r16,$83
out tccr0a,r16 ; set to noninverted mode, oc0a compare match
ldi r16,$01
out tccr0b,r16 ; set to fast pwm mode, ck = Fcpu = 8MHz
ldi r16,$01
sts timsk0,r16 ; turn on the overflow interrupt

;commented out for the time being - if you erase it, change power register
;setup t1 for button scan timing and state update
;ldi r16,$00
;sts tccr1a,r16
;ldi r16,$13
;sts tccr1b,r16 ; set to pwm phase/freq correct, top = icr1, ck = Fcpu/64
;ldi r16,$00
;sts tccr1c,r16
;ldi r16,$08
;sts icr1h,r16
;ldi r16,$00
;sts icr1l,r16 ; set counter top to $0800 (30.5hz)
;ldi r16,$00 ; main checks buttons every other - so 15hz scan rate
;sts timsk1,r16 ; turn off overflow interrupt

;setup t2 for lfo, button, and led scan timing
;293hz for lfo scan, 880hz (16x55hz) for led/button scan
ldi r16,$01
sts tccr2a,r16
ldi r16,$0c
sts tccr2b,r16 ; set to pwm phase/freq correct, top = 0cr2a, ck = Fcpu/64
ldi r16,$d5
sts ocr2a,r16 ; set counter top to $d5
ldi r16,$55
sts ocr2b,r16 ; set interrupt to 1/3 max, $47
ldi r16,$07
sts timsk2,r16 ; turn on overflow, ocr2a, ocr2b interrupts

;setup adc to read slider
ldi r16,$66
sts admux,r16 ; set to internal vref = vcc, sample adc6, left adjust result
ldi r16,$c7
sts adcsra,r16 ; turn on adc, single sample mode, ck = Fcpu/128 = 62.5kHz
ldi r16,$00
sts adcsrb,r16 ; free running mode

;setup registers
ldi r16,$40
sts buttondata_counter,r16 ; set button counter to top
ldi r16,$50
sts buttondata_pointer,r16 ; set button data pointer to bottom
ldi r16,$01
mov r11,r16 ; led scan bit
ldi r16,$ff
mov r12,r16 ; turn all leds off
ldi r16,$00
mov r10,r16 ; initialize null register
sts pad1_state,r10
sts pad2_state,r10
sts pad1_prev,r10
sts pad2_prev,r10 ; set all buttons to off
out gpior0,r10
in r16,gpior1
andi r16,$0f
out gpior1,r16 ; clear record/erase bits
ldi r16,$08
out gpior2,r16 ; set synthstate to voice a
mov r13,r16 ; turn voice a led on
ldi r16,$0c
out eedr,r16 ; set voice to a
sts note_trigger,r10 ; set notes to off
sts note1_voice,r16
sts note2_voice,r16
sts note3_voice,r16
sts note4_voice,r16 ; set all voices to sine
ldi r26,$00
ldi r27,$02 ; initialize delay pointer
ldi r28,$00
ldi r29,$01 ; initialize pattern pointer
sts note_amp_state,r10 ; set all notes to off
sts note1_amp,r10
sts note2_amp,r10
sts note3_amp,r10
sts note4_amp,r10 ; set all notes to off
clr r20
clr r21
clr r22
clr r23
clr r24 ; set all notes to off
ldi r16,$40
sts note_counter,r16 ; set note counter to start 1s after start
ldi r16,$03
sts fm_value,r16 ; set fm vlaue
sts note_scheduler,r10 ; set all notes free

;setup note table in sram ($0820 - $083f)
;voice d table
ldi r16,$04
sts $0821,r16
ldi r16,$08
sts $0822,r16
ldi r16,$09
sts $0823,r16
ldi r16,$0c
sts $0824,r16
ldi r16,$10
sts $0825,r16
ldi r16,$12
sts $0826,r16
;voice a table
ldi r16,$08
sts $0829,r16
ldi r16,$09
sts $082a,r16
ldi r16,$0c
sts $082b,r16
ldi r16,$10
sts $082c,r16
ldi r16,$12
sts $082d,r16
ldi r16,$18
sts $082e,r16
;voice b table
ldi r16,$10
sts $0831,r16
ldi r16,$12
sts $0832,r16
ldi r16,$18
sts $0833,r16
ldi r16,$1b
sts $0834,r16
ldi r16,$20
sts $0835,r16
ldi r16,$24
sts $0836,r16
;voice c table
ldi r16,$20
sts $0839,r16
ldi r16,$24
sts $083a,r16
ldi r16,$30
sts $083b,r16
ldi r16,$36
sts $083c,r16
ldi r16,$40
sts $083d,r16
ldi r16,$48
sts $083e,r16

;set attack/decay lookup table
ldi r16,$40
sts $0840,r16 ; voice d attack
ldi r16,$02
sts $0841,r16 ; voice d decay
ldi r16,$01
sts $0842,r16 ; voice a attack
ldi r16,$01
sts $0843,r16 ; voice a decay
ldi r16,$20
sts $0844,r16 ; voice b attack
ldi r16,$01
sts $0845,r16 ; voice b decay
ldi r16,$40
sts $0846,r16 ; voice c attack
ldi r16,$04
sts $0847,r16 ; voice c decay


;setup interrupts
ldi r16,$03
sts eicra,r16 ; set int0 to rising edge
ldi r16,$07
out tifr2,r16 ; clear any pending interrupts
ldi r16,$01
out eifr,r16 ; clear any pending interrupts
out tifr0,r16 ; clear any pending interrupts
out tifr1,r16 ; clear any pending interrupts
nop ; for good measure
out eimsk,r16 ; enable int0 interrupt
sei ; turn on interrupts

main: ; button checking and state update
; data is processed on a somewhat regular interrupt determined by t2

pad2: ; check pads7:12
; assuming r25 holds positive valued button presses
; assuming portd has already been switched to next sample state

sbic portd,$00 ; check which pads are being scanned
rjmp pad1 ; go get pad1:6 data
lds r17,pad2_state
sts pad2_prev,r17 ; back up previous state
sts pad2_state,r25 ; save current state

synth_effect_state: ; toggle state when buttons pressed

eor r17,r25 ; check if button state change
and r17,r25 ; check if button rising edge
sbrs r25,$06 ; check if shift is pressed
rjmp synth_voice_state
in r16,gpior1 ; fetch current shift synth state
eor r17,r16 ; change shift state if rising edge
out gpior1,r17 ; change effect state

;check if erase and rec are set
sbrs r17,$04 ; check if rec is set
rjmp checknote
sbrs r17,$05 ; check if erase is set
rjmp checknote
sts pattern_top_lsb,r10
ldi r16,$01
sts pattern_top_msb,r16 ; set pattern top to bottom
mov yl,r10
mov yh,r16 ; set pattern pointer to bottom
andi r17,$1f
out gpior1,r17 ; clear the erase bit
ldi r17,$c0
mov r12,r17 ; set all leds on to inidicate erase
rjmp checknote ; finish off

synth_voice_state: ; index to next button when pressed

andi r17,$0f ; mask off voice bits
breq checknote ; check if none set, dont change

;make sure only 1 bit is set
sbrc r17,$03
ldi r17,$08
sbrc r17,$02
ldi r17,$04
sbrc r17,$01
ldi r17,$02
out gpior2,r17 ; change voice state
;set current voice - voice lookup table hardcoded here
sbrc r17,$03
ldi r16,$0c ; set voice a
sbrc r17,$02
ldi r16,$14 ; set voice b
sbrc r17,$01
ldi r16,$1c ; set voice c
sbrc r17,$00
ldi r16,$24 ; set voice d
out eedr,r16 ; save current voice

rjmp checknote ; finish off

pad1: ; check pads1:6

sbrc r25,$06 ; dont read wheel data if shift is being pressed
rjmp checknote ; finish off

pad1_check: ; check pad1:6 for button presses

lds r17,pad1_state
sts pad1_prev,r17 ; back up previous state
sts pad1_state,r25 ; save current state

;set leds to current state (clears during playback)
ldi r16,$ff
eor r16,r25 ; inverted logic for pad1 leds
mov r12,r16 ; illuminate lights while pressed

;check for pad1 rising edges
eor r17,r25 ; check if button state change
and r17,r25 ; check if button rising edge
sts note_trigger,r17 ; save new button presses


checknote: ; see if its time to play/record a note

in r16,gpior1 ; fetch pad2 shift state
sbrc r16,$04 ; check if recording or playing
rjmp writenote

;play out any new notes being triggered
lds r17,note_trigger ; get button press state
tst r17 ; check if new notes
breq checknote1 ; load old notes
ldi r16,$07 ; prep note counter

write_check2: ; check which notes are pressed

dec r16
breq checknote1 ; check if 6 notes checked
lsr r17 ; shift note trigger to carry
brcc write_check2 ; if no note, keep checking

;process new notes
in zl,eedr ; fetch current voice
sts note_voice_temp,zl ; prep for noteplay
andi zl,$18
ori zl,$20 ; set voice to lookup table position
or zl,r16 ; set note to lookup table position
ldi zh,$08 ; prep fetch pointer
ld r25,z ; fetch appropriate note from note table
sts note_value_temp,r25 ; prep for playnote call
push r16
push r17
rcall playnote ; play note as its pressed - clobbers all registers
pop r17
pop r16
tst r17 ; check if any notes left
brne write_check2 ; load new notes

checknote1: ; load notes from memory

sts note_trigger,r10 ; clear new note register
lds r16,note_counter ; fetch time since last note
dec r16 ; decrement note counter
sts note_counter,r16 ; restore time since last note
breq play_new_note ; check if time expired
rjmp led_update ; dont play out if not time yet

play_new_note:

lds r16,pattern_top_lsb
lds r17,pattern_top_msb ; get top of current pattern
cp r28,r16
cpc r29,r17 ; check if at top
brcs load_note
clr r28
ldi r29,$01 ; set to bottom
cp r28,r16
cpc r29,r17 ; check if top is bottom
brcs load_note
rjmp led_update

load_note: ; get current note information and schedule notes

ld r25,y+ ; fetch time till next note
sts note_counter,r25 ; load new note counter
ld r16,y+ ; fetch voice
ld r17,y+ ; fetch frequency
sts note_voice_temp,r16 ; store voicing information
sts note_value_temp,r17 ; store frequency information
rcall playnote ; play out to free voice - clobbers all registers
ld r17,y+ ; fetch led pattern
ldi r16,$ff
eor r16,r17 ; flip bits for led playback
ori r16,$c0 ; mask off unused bits (inverted logic)
mov r12,r16 ; set pad1 leds accordingly
lds r16,note_counter
tst r16 ; check if time till next note is 0
breq play_new_note ; fetch and play next note

playnote_done:

lds r16,pattern_top_lsb
lds r17,pattern_top_msb
cp r28,r16
cpc r29,r17 ; check if at top
brcc reset_pointer
rjmp led_update ; finish off if not at top

reset_pointer: ; set to bottom

clr r28
ldi r29,$01 ; set to bottom
rjmp led_update

writenote: ; write notes to pattern memory (no y register rollover protection yet)

lds r16,note_counter ; fetch time since last note
inc r16 ; increment note counter
sts note_counter,r16 ; store note counter
brne write_check ; check for new notes if not done
lds r30,pattern_top_lsb
lds r31,pattern_top_msb
cp r30,yl
cpc r31,yh ; see if no notes have been stored
breq write_repeat ; keep going if no new notes
ldi r16,$01 ; set counter to play on next note
sts note_counter,r16 ; set note counter to read mode
in r16,gpior1
andi r16,$0f
out gpior1,r16 ; clear record/erase bits
rjmp led_update ; finish off

write_repeat: ; keep checking since no notes set

ldi r16,$80 ; reset counter
sts note_counter,r16 ; set note counter to read mode

write_check: ; see if new note pressed

lds r17,note_trigger ; get button press state
tst r17 ; check if new notes
breq led_update ; load new notes
sts pattern_backup_lsb,yl
sts pattern_backup_msb,yh ; back up current pattern pointer
lds yl,pattern_top_lsb
lds yh,pattern_top_msb ; fetch top of pattern
ldi r16,$07 ; prep note counter

write_check1: ; check which notes are pressed

dec r16
breq writenote_done ; check if 6 notes checked
lsr r17 ; shift note trigger to carry
brcc write_check1 ; if no note, keep checking

loadbits:

lds r25,note_counter
andi r25,$7f ; mask off read bit
st y+,r25 ; store time since last note
subi yl,$05 ; index back to previous note
brcs backindex_clear
st y,r25 ; store previous time

backindex_clear: ; dont store previous time because there isnt one

subi yl,$fb ; reset pointer
in zl,eedr ; fetch current voice
st y+,zl ; store current voice
sts note_voice_temp,zl ; prep for noteplay
andi zl,$18
ori zl,$20 ; set voice to lookup table position
or zl,r16 ; set note to lookup table position
ldi zh,$08 ; prep fetch pointer
ld r25,z ; fetch appropriate note from note table
st y+,r25 ; store current frequency
sts note_value_temp,r25 ; prep for playnote call
lds r25,note_trigger ; get button press state
st y+,r25 ; store led pattern
ldi r30,$ff
eor r30,r25 ; flip bits for led playback
ori r30,$c0 ; mask off unused bits (inverted logic)
mov r12,r30 ; set pad1 leds accordingly
push r16
push r17
rcall playnote ; play note as its pressed - clobbers all registers
pop r17
pop r16
ldi r25,$80
sts note_counter,r25 ; reset note counter - write bit set
tst r17 ; check if any notes left
brne write_check1 ; load new notes

writenote_done: ; finish off pattern write

sts note_trigger,r10 ; clear new note register
sts pattern_top_lsb,yl
sts pattern_top_msb,yh ; store new pattern top
lds yl,pattern_backup_lsb
lds yh,pattern_backup_msb ; restore pattern pointer

led_update: ; do led stuff

lds r16,led_blink_timer ; fetch current blink time
dec r16 ; decrement led blink counter
sts led_blink_timer,r16 ; store new blink time
andi r16,$0f
brne interrupt_wait ; finish off if not time yet
brts blink_on
in r16,gpior2 ; get voice state
mov r13,r16 ; set leds to off
set
rjmp blink_done

blink_on:

lds r16,led_flip
sbrs r16,$07 ; check if flip bit is set
rjmp blink_on_alt
in r16,gpior1 ; get shift register
in r17,gpior2 ; get voice state
or r16,r17
mov r13,r16 ; set leds on
sts led_flip,r10 ; clear flip bit
clt
rjmp blink_done

blink_on_alt:

in r16,gpior1 ; get shift register
in r17,gpior2 ; get voice
eor r16,r17
mov r13,r16 ; set leds on
ldi r16,$80
sts led_flip,r16 ; set flip bit
clt

blink_done:

ldi r16,$07
sts led_blink_timer,r16 ; reset counter

interrupt_wait: ; keep everything on a consistent timer

lds r30,buttondata_pointer ; fetch current position
sbrs r30,$05 ; check for overflow
rjmp interrupt_wait ; keep checking
;set to read pad1:6
ldi r17,(0<<pd7)|(0<<pd6)|(0<<pd5)|(0<<pd4)|(1<<pd3)|(1<<pd2)|(1<<pd1)|(0<<pd0)
sbis portd,$00 ; check which pads were being scanned
;set to read pad7:12
ldi r17,(0<<pd7)|(0<<pd6)|(0<<pd5)|(0<<pd4)|(1<<pd3)|(1<<pd2)|(0<<pd1)|(1<<pd0)
out portd,r17 ; switch to other set of pads
clr r25 ; prep register for storing button result

button_averaging_setup: ; prepare to be counted

ldi r30,$50
ldi r31,$08 ; setup for data location
clr r17 ; clear summing register

button_averaging: ; check if buttons have been pressed

ld r16,z ; fetch data
lsr r16 ; put first bit in carry
adc r17,r10 ; sum carry bits
st z+,r16 ; restore data
sbrs r30,$05 ; check if done with first column
rjmp button_averaging

button_threshold: ; check if over threshold

cpi r17,$07 ; check if more than (half - 1) of the samples were low
brsh load_zero ; inversion of bits is done here
ori r25,$80

load_zero: ; dont do anything if not above threshold

lsr r25 ; shift bit over - will eventually get to the right position
lds r16,buttondata_counter ; fetch current position
lsr r16
sts buttondata_counter,r16 ; restore counter
brcc button_averaging_setup ; go back and do next set
ldi r16,$40
sts buttondata_counter,r16 ; reset counter
ldi r16,$50
sts buttondata_pointer,r16 ; reset pointer

;do slider
lds r30,slider_low ; fetch slider info
lds r31,slider_high
sts slider_low,r10 ; reset accumulator
sts slider_high,r10
ldi r16,$50
sts buttondata_pointer,r16 ; reset pointer
;shift down by 4
swap r30
swap r31
andi r30,$0f ; mask off unused bits
or r30,r31 ; assuming high nibble is always 0
cpi r30,$f8 ; check if slider in use
brsh adc_clear
swap r30 ; formulate a decent note range - 32 notes
andi r30,$0f ; 16 notes
ldi r31,$2e ; set to lookup table address
lpm r24,z ; fetch frequency and load playback register
rjmp main ; do it all over again

adc_clear: ; adc not in use, set to off

mov r24,r10 ; set slider to off
rjmp main ; do it all over again


t0int: ; sample data processed here
; average loop time needs to be kept under 200 clock cycles or so

.include "playback.inc"
;.include "playback_signed.asm"

t1int: ; button scanning and state update
; not used - done in main. just placed here in case?
reti ; return


t2int_lfo: ; lfo and envelope generation

;store used registers
push r30
push r31
in r30,sreg
push r30

;do fm
in r30,gpior1 ; fetch effect register
sbrs r30,$03 ; check if fm is set
rjmp envelopes
lds r30,fm_value
neg r30
sts fm_value,r30
cpse r20,r10
add r20,r30
cpse r21,r10
add r21,r30
cpse r22,r10
add r22,r30
cpse r23,r10
add r23,r30
cpse r24,r10
add r24,r30

envelopes: ; calculate envelopes
;00 = off, 01 = trigger, 10 = rising, 11 = falling

lds r31,note_amp_state ; get amplitude state
mov r30,r31 ; move to temp register
andi r30,$03 ; mask off note1 state
breq note2_envelope ; go to next note if note1 not active
cpi r30,$01 ; check if note1 trigger
breq note1_start
cpi r30,$02 ; check if note1 rising edge
breq note1_rising
;else do falling edge
lds r30,note1_amp ; fetch current amplitude
lds r19,note1_decay ; fetch decay rate
sub r30,r19 ; decrement amplitude
sts note1_amp,r30 ; store amplitude
brcc note2_envelope ; go to next note if note at top
sts note1_amp,r10 ; set amplitude to 0
andi r31,$fc ; set note1 state to note off
lds r30,note_scheduler
andi r30,$fe
sts note_scheduler,r30 ; free up this note
rjmp note2_envelope ; go to next note

note1_start: ; initiate an envelope

sts note1_amp,r10 ; set note1 amplitude to 0
andi r31,$fc
ori r31,$02 ; set note1 state to rising edge
rjmp note2_envelope ; go to next note

note1_rising: ; do amplitude increment

lds r30,note1_amp ; fetch current amplitude
lds r19,note1_attack ; fetch attack rate
add r30,r19 ; increment amplitude
sts note1_amp,r30 ; store amplitude
brcc note2_envelope ; go to next note if not at top
ldi r30,$ff ; set amplitude to max
sts note1_amp,r30 ; store amplitude
ori r31,$01 ; set note1 state to falling edge

note2_envelope: ; do note2 envelope generation

mov r30,r31 ; move note_state to temp register
andi r30,$0c ; mask off note2 state
breq note3_envelope ; go to next note if note1 not active
cpi r30,$04 ; check if note trigger
breq note2_start
cpi r30,$08 ; check if note rising edge
breq note2_rising
;else do falling edge
lds r30,note2_amp ; fetch current amplitude
lds r19,note2_decay ; fetch decay rate
sub r30,r19 ; decrement amplitude
sts note2_amp,r30 ; store amplitude
brcc note3_envelope ; go to next note if note at top
sts note2_amp,r10 ; set amplitude to 0
andi r31,$f3 ; set note state to note off
lds r30,note_scheduler
andi r30,$fd
sts note_scheduler,r30 ; free up this note
rjmp note3_envelope ; go to next note

note2_start: ; initiate an envelope

sts note2_amp,r10 ; set note1 amplitude to 0
andi r31,$f3
ori r31,$08 ; set note1 state to rising edge
rjmp note3_envelope ; go to next note

note2_rising: ; do amplitude increment

lds r30,note2_amp ; fetch current amplitude
lds r19,note2_attack ; fetch attack rate
add r30,r19 ; increment amplitude
sts note2_amp,r30 ; store amplitude
brcc note3_envelope ; go to next note if not at top
ldi r30,$ff ; set amplitude to max
sts note2_amp,r30 ; store amplitude
ori r31,$04 ; set note state to falling edge


note3_envelope: ; do note3 envelope generation

mov r30,r31 ; move to temp register
andi r30,$30 ; mask off note1 state
breq note4_envelope ; go to next note if note1 not active
cpi r30,$10 ; check if note trigger
breq note3_start
cpi r30,$20 ; check if note rising edge
breq note3_rising
;else do falling edge
lds r30,note3_amp ; fetch current amplitude
lds r19,note3_decay ; fetch decay rate
sub r30,r19 ; decrement amplitude
sts note3_amp,r30 ; store amplitude
brcc note4_envelope ; go to next note if note at top
sts note3_amp,r10 ; set amplitude to 0
andi r31,$cf ; set note1 state to note off
lds r30,note_scheduler
andi r30,$fb
sts note_scheduler,r30 ; free up this note
rjmp note4_envelope ; go to next note

note3_start: ; initiate an envelope

sts note3_amp,r10 ; set note1 amplitude to 0
andi r31,$cf
ori r31,$20 ; set note1 state to rising edge
rjmp note4_envelope ; go to next note

note3_rising: ; do amplitude increment

lds r30,note3_amp ; fetch current amplitude
lds r19,note3_attack ; fetch attack rate
add r30,r19 ; increment amplitude
sts note3_amp,r30 ; store amplitude
brcc note4_envelope ; go to next note if not at top
ldi r30,$ff ; set amplitude to max
sts note3_amp,r30 ; store amplitude
ori r31,$10 ; set note state to falling edge

note4_envelope: ; do note4 envelope

mov r30,r31 ; move to temp register
andi r30,$c0 ; mask off note1 state
breq envelope_done ; finish off if not active
cpi r30,$40 ; check if note trigger
breq note4_start
cpi r30,$80 ; check if note rising edge
breq note4_rising
;else do falling edge
lds r30,note4_amp ; fetch current amplitude
lds r19,note4_decay ; fetch decay rate
sub r30,r19 ; decrement amplitude
sts note4_amp,r30 ; store amplitude
brcc envelope_done ; finish off if note at top
sts note4_amp,r10 ; set amplitude to 0
andi r31,$3f ; set note state to note off
lds r30,note_scheduler
andi r30,$f7
sts note_scheduler,r30 ; free up this note
rjmp envelope_done ; finish off

note4_start: ; initiate an envelope

sts note4_amp,r10 ; set note1 amplitude to 0
andi r31,$3f
ori r31,$80 ; set note1 state to rising edge
rjmp envelope_done ; finish off

note4_rising: ; do amplitude increment

lds r30,note4_amp ; fetch current amplitude
lds r19,note4_attack ; fetch attack rate
add r30,r19 ; increment amplitude
sts note4_amp,r30 ; store amplitude
brcc envelope_done ; finish off if not at top
ldi r30,$ff ; set amplitude to max
sts note4_amp,r30 ; store amplitude
ori r31,$40 ; set note state to falling edge

envelope_done: ; finish off

sts note_amp_state,r31 ; save new state


t2_int_done: ; finish off

pop r30
out sreg,r30
pop r31
pop r30 ; restore used registers
reti ; return


t2int_led: ; led scanning

;store used registers
push r30
in r30,sreg
push r30
push r31

;fetch button data
lds r30,buttondata_pointer ; get current location
sbrc r30,$05 ; check for overflow
rjmp lfo_calculate ; stop storing till reset
in r19,pinc ; get button values
andi r19,$3f ; mask off buttons
sbic pind,$04 ; check if shift button pressed
ori r19,$40 ; set shift button bit if button is high
ldi r31,$08 ; prepare for data loading
st z+,r19 ; store button values
sts buttondata_pointer,r30 ; update pointer
;fetch slider data
lds r19,adch
lds r30,slider_low
lds r31,slider_high
add r30,r19
adc r31,r10
sts slider_low,r30
sts slider_high,r31
ldi r19,$c7
sts adcsra,r19 ; start next adc sample

lfo_calculate: ; calculate lfo value from lookup table

lds r30,lfo_lsb ; fetch lfo pointer
inc r30 ; increment lfo
andi r30,$7f ; limit to 128 values
ldi r31,$2c ; mask off lfo table position
lpm r19,z ; fetch lfo value
out eearl,r19 ; store lfo value
sts lfo_lsb,r30 ; replace lfo pointer

;update led state
sbic portb,$06 ; check if 1:6 or 7:11 leds being scanned
rjmp led1_check ; scan 1:6 leds
sbrc r11,$05 ; check if done scanning led7:11
rjmp led2_flip ; change direction
mov r30,r11
and r30,r13 ; mask off leds that should be lit
andi r30,$bf ; make sure led control is low
ori r30,$80 ; keep nc pin high
out portb,r30
lsl r11 ; index to next led

;finish off
pop r31
pop r30
out sreg,r30
pop r30 ; restore used registers
reti ; return

led2_flip: ; change which leds are being controlled

lsl r11 ; index to next led
ldi r30,$ff
out portb,r30 ; set to led1:6, all off

;finish off
pop r31
pop r30
out sreg,r30
pop r30 ; restore used registers
reti ; return

led1_flip:

ldi r30,$01
mov r11,r30 ; index bit back into register
ldi r30,$80
out portb,r30 ; switch to led2, turn all leds off

;finish off
pop r31
pop r30
out sreg,r30
pop r30 ; restore used registers
reti ; return

led1_check:

lsr r11 ; index led register
breq led1_flip ; check if all leds scanned
ldi r30,$ff
eor r30,r11 ; invert led register
or r30,r12 ; mask off current led
ori r30,$c0 ; make sure led control and nc is high
out portb,r30 ; turn on led

;finish off
pop r31
pop r30
out sreg,r30
pop r30 ; restore used registers
reti ; return


playnote: ; function for selecting voices and playing notes

.include "note_scheduler.asm"


.org $0600
.include "sine_2k.inc" ; 8 bit, 2048 sample, sinewave

.org $0a00
.include "saw_low_2k.inc" ; 8 bit, 2048 sample, low passed rampwave

.org $0e00
.include "square_low_2k.inc" ; 8 bit, 2048 sample, low passed square wave

.org $1200
.include "noise_2k.inc"; 8 bit, 2048 sample, bandpassed noise

.org $1600
.include "sine_128.inc" ; 8 bit, 128 sample sinewave table for lfo

.org $1700
.include "slider_16.inc" ; 16 note frequency chart for slider

wakeup: ; wakeup/sleep routine

ldi r16,$ff ; delay for 100ms or so to let things settle out

loop2:

ldi r17,$ff

loop1:

nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
dec r17
brne loop1
dec r16
brne loop2

lds r16,eicra ; fetch interrupt control register
andi r16,$03 ; mask off int0
tst r16 ; check if current interrupt was low level
brne sleepstate ; initiate wakeup if so
jmp start ; go to initialization routine

sleepstate: ; get ready for bed

ldi r16,$00
sts eicra,r16 ; set int0 to low level
ldi r16,$01
out eifr,r16 ; clear any pending interrupts

;shut off t0
ldi r16,$00
out tccr0b,r16 ; turn off t0
sts timsk0,r16 ; turn off t0 interrupt
ldi r16,$01
out tifr0,r16 ; clear any pending interrupts

;turn off t1
ldi r16,$00
sts tccr1a,r16
sts tccr1b,r16 ; turn off t1
sts tccr1c,r16
sts timsk1,r16 ; turn off overflow interrupt
ldi r16,$01
out tifr1,r16 ; clear any pending interrupts

;turn off t2
ldi r16,$00
sts tccr2a,r16
sts tccr2b,r16 ; turn off t0
sts timsk2,r16 ; turn on overflow interrupt
ldi r16,$07
out tifr2,r16 ; clear any pending interrupts

;turn off adc
ldi r16,$00
sts adcsra,r16
sts admux,r16 ; turn off vref

;setup power register
ldi r16,$ef
sts prr,r16 ; turn everything off

;setup ports for sleep
ldi r16,$80
out portb,r16 ; turn off leds
ldi r16,$7f
out portc,r16 ; turn on pullups for all portc
ldi r16,(0<<pd7)|(0<<pd6)|(0<<pd5)|(1<<pd4)|(0<<pd3)|(1<<pd2)|(1<<pd1)|(1<<pd0)
out portd,r16 ; shut off pad controls and turn on pullup for shift button

;go to sleep
ldi r16,$05
out smcr,r16 ; enable sleep mode, power down mode
nop
nop
nop
sei ; turn interrupts back on so we can wakeup again
sleep
nop
nop
nop
rjmp wakeup

