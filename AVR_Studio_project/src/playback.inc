; playback.inc
; note playback file for t0 interrupt routine sample calculator
;
; data is saved in r19 and written out at the top of the function
; this is done to create a 1 sample buffer in case of interrupt blocking

out ocr0a,r18 ; update sample
in r19,sreg
out gpior0,r19 ; store here to save a few cycles
clr r19 ; prep for playback
clr r18
push r25
push r30
push r31

;play notes if they are ready
tst r20 ; check if note1 playing
breq play2
add r2,r20
adc r3,r10 ; increment note1 counter
movw z,r3:r2
andi r31,$07 ; mask off unused bits
lds r25,note1_voice
or r31,r25
lpm r25,z ; fetch note1 value
lds r30,note1_amp
mul r25,r30 ; multiply by amplitude
mov r18,r1

play2:

tst r21 ; check if note2 playing
breq play3
add r4,r21
adc r5,r10 ; increment note2 counter
movw z,r5:r4
andi r31,$07 ; mask off unused bits
lds r25,note2_voice
or r31,r25 ; set to correct lookup table
lpm r25,z
lds r30,note2_amp
mul r25,r30 ; multiply by amplitude
add r18,r1
adc r19,r10

play3:

tst r22 ; check if note2 playing
breq play4
add r6,r22
adc r7,r10 ; increment note2 counter
movw z,r7:r6
andi r31,$07 ; mask off unused bits
lds r25,note3_voice
or r31,r25 ; set to correct lookup table
lpm r25,z
lds r30,note3_amp
mul r25,r30 ; multiply by amplitude
add r18,r1
adc r19,r10

play4:

tst r23 ; check if note2 playing
breq play5
add r8,r23
adc r9,r10 ; increment note2 counter
movw z,r9:r8
andi r31,$07 ; mask off unused bits
lds r25,note4_voice
or r31,r25 ; set to correct lookup table
lpm r25,z
lds r30,note4_amp
mul r25,r30 ; multiply by amplitude
add r18,r1
adc r19,r10

play5:

tst r24 ; check if slider active
breq effect1
add r14,r24
adc r15,r10 ; increment slider counter
movw z,r15:r14
andi r31,$07 ; mask off unused bits
in r25,eedr ; get current voice
or r31,r25
lpm r25,z
add r18,r25
adc r19,r10

effect1: ; process effects

lsr r19
ror r18
lsr r19
ror r18 ; divide value by 4
in r19,gpior1
sbrs r19,$01 ; check if bitcrush effect bit is set
rjmp effect2
andi r18,$f0 ; but crush to 4 bits

effect2: ; process effect2

sbrs r19,$02 ; check if delay effect bit is set
rjmp effect3
ld r25,x
ldi r30,$03
mul r25,r30
add r0,r18
adc r1,r10
lsr r1
ror r0
lsr r1
ror r0 ; 3/4 feedback
mov r18,r0
st x+,r18
cpi xh,$08
brne effect3
ldi xh,$02

effect3: ; process effect3 - no effect4, fm is done in the lfo loop

sbrs r19,$00 ; check if delay effect bit is set
rjmp sendout
in r30,eearl ; get lfo signal
mul r18,r30 ; multiply lfo by signal
add r18,r1 ; add signals together
ror r18 ; divide by 2 - for half depth tremolo

sendout:

;finish off
pop r31
pop r30
pop r25
in r19,gpior0
out sreg,r19
reti



