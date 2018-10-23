; assuming r25 holds positive valued button presses
; assuming portd has already been switched to next sample state

pad2: ; check pads7:12

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
