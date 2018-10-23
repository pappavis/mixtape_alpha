; note_scheduler.asm
; this function does the 4 voice polyphony and sets up the playback registers
; because all working registers are consumed by the function,
; the notes and voices 

;check which voices are free - take first available
lds r25,note_scheduler
sbrs r25,$03
rjmp playnote4
sbrs r25,$02
rjmp playnote3
sbrs r25,$01
rjmp playnote2
sbrs r25,$00
rjmp playnote1

;if all notes are taken, steal note with lowest amplitude, and decaying
; the stolen note keeps its amplitude, but changes pitch
; and voice, and gets set rising
ldi r16,$ff
mov r17,r16
movw r31:r30,r17:r16 ; prep all registers with max value
cpi r25,$c0 ; check if note4 decaying
brlo note3check
lds r16,note4_amp ; load amplitude

note3check:

andi r25,$3f ; mask off note3
cpi r25,$30 ; check if note3 decaying
brlo note2check
lds r17,note3_amp ; load amplitude

note2check:

andi r25,$0f ; mask off note2
cpi r25,$0c ; check if note2 decaying
brlo note1check
lds r30,note2_amp ; load amplitude

note1check:

andi r25,$03 ; mask off note1
cpi r25,$03 ; check if note1 decaying
brlo notecomp ; compare amplitudes
lds r31,note1_amp ; load amplitude

notecomp: ; all decaying amplitudes loaded, rest at max

lds r25,note_scheduler ; reset note scheduler
cp r16,r17 ; check if note4 > note3
brsh note3low ; note3 lower
;note4 lower
cp r30,r31 ; check if note2 > note1
brlo note2low ; note2 lower
;note1 lower
cp r16,r31 ; check if note4 > note1
brsh stealnote1 ; if note1 < note4, steal note1
rjmp stealnote4 ; if note4 < note1, steal note4

note3low: ; note3 < note4, rest unknown

cp r30,r31 ; check if note2 > note1
brlo note1high ; note2 lower
;note1 lower
cp r17,r31 ; check if note3 > note1
brsh stealnote1 ; if note1 < note3, steal note1
rjmp stealnote3 ; if note3 < note1, steal note3

note2low: ; note4 < note3, note2 < note1

cp r16,r30 ; check if note4 > note2
brsh stealnote2 ; if note2 < note4, steal note2
rjmp stealnote4 ; if note4 < note2, steal note4

note1high: ; note3 < note4, note2 < note1

cp r17,r30 ; check if note3 > note2
brsh stealnote2 ; if note2 < note3, steal note2
rjmp stealnote3 ; if note3 < note2, steal note3

stealnote1: ; else set note rising if stealing (done above)

lds zl,note_voice_temp ; fetch voice
lds r17,note_value_temp ; fetch frequency
sts note1_voice,zl ; store voicing information
mov r20,r17 ; load note1 frequency register
andi zl,$18
lsr zl
lsr zl
ori zl,$40 ; set to lookup table position
ldi zh,$08 ; prep fetch pointer
ld r16,z ; fetch attack
sts note1_attack,r16 ; set attack
inc zl
ld r16,z ; fetch decay
sts note1_decay,r16 ; set decay
lds r16,note_amp_state ; fetch note amp state
andi r16,$fc ; mask off note1
ori r16,$02 ; set note1 rising
sts note_amp_state,r16 ; save note amp state
ori r25,$01
sts note_scheduler,r25 ; set note1 as taken
ret

stealnote2: ; else set note rising if stealing (done above)

lds zl,note_voice_temp ; fetch voice
lds r17,note_value_temp ; fetch frequency
sts note2_voice,zl ; store voicing information
mov r21,r17 ; load note1 frequency register
andi zl,$18
lsr zl
lsr zl
ori zl,$40 ; set to lookup table position
ldi zh,$08 ; prep fetch pointer
ld r16,z ; fetch attack
sts note2_attack,r16 ; set attack
inc zl
ld r16,z ; fetch decay
sts note2_decay,r16 ; set decay
lds r16,note_amp_state ; fetch note amp state
andi r16,$f3 ; mask off note2
ori r16,$08 ; set note2 rising
sts note_amp_state,r16 ; save note amp state
ori r25,$02
sts note_scheduler,r25 ; set note1 as taken
ret

stealnote3: ; else set note rising if stealing (done above)

lds zl,note_voice_temp ; fetch voice
lds r17,note_value_temp ; fetch frequency
sts note3_voice,zl ; store voicing information
mov r22,r17 ; load note1 frequency register
andi zl,$18
lsr zl
lsr zl
ori zl,$40 ; set to lookup table position
ldi zh,$08 ; prep fetch pointer
ld r16,z ; fetch attack
sts note3_attack,r16 ; set attack
inc zl
ld r16,z ; fetch decay
sts note3_decay,r16 ; set decay
lds r16,note_amp_state ; fetch note amp state
andi r16,$cf ; mask off note3
ori r16,$20 ; set note3 rising
sts note_amp_state,r16 ; save note amp state
ori r25,$04
sts note_scheduler,r25 ; set note1 as taken
ret

stealnote4: ; else set note rising if stealing (done above)

lds zl,note_voice_temp ; fetch voice
lds r17,note_value_temp ; fetch frequency
sts note4_voice,zl ; store voicing information
mov r23,r17 ; load note1 frequency register
andi zl,$18
lsr zl
lsr zl
ori zl,$40 ; set to lookup table position
ldi zh,$08 ; prep fetch pointer
ld r16,z ; fetch attack
sts note4_attack,r16 ; set attack
inc zl
ld r16,z ; fetch decay
sts note4_decay,r16 ; set decay
lds r16,note_amp_state ; fetch note amp state
andi r16,$3f ; mask off note4
ori r16,$80 ; set note4 rising
sts note_amp_state,r16 ; save note amp state
ori r25,$08
sts note_scheduler,r25 ; set note4 as taken
ret

playnote1: ; else set note rising if stealing (done above)

lds zl,note_voice_temp ; fetch voice
lds r17,note_value_temp ; fetch frequency
sts note1_voice,zl ; store voicing information
mov r20,r17 ; load note1 frequency register
andi zl,$18
lsr zl
lsr zl
ori zl,$40 ; set to lookup table position
ldi zh,$08 ; prep fetch pointer
ld r16,z ; fetch attack
sts note1_attack,r16 ; set attack
inc zl
ld r16,z ; fetch decay
sts note1_decay,r16 ; set decay
lds r16,note_amp_state ; fetch note amp state
andi r16,$fc ; mask off note1
ori r16,$01 ; set note1 trigger
sts note_amp_state,r16 ; save note amp state
ori r25,$01
sts note_scheduler,r25 ; set note1 as taken
ret

playnote2: ; else set note rising if stealing (done above)

lds zl,note_voice_temp ; fetch voice
lds r17,note_value_temp ; fetch frequency
sts note2_voice,zl ; store voicing information
mov r21,r17 ; load note1 frequency register
andi zl,$18
lsr zl
lsr zl
ori zl,$40 ; set to lookup table position
ldi zh,$08 ; prep fetch pointer
ld r16,z ; fetch attack
sts note2_attack,r16 ; set attack
inc zl
ld r16,z ; fetch decay
sts note2_decay,r16 ; set decay
lds r16,note_amp_state ; fetch note amp state
andi r16,$f3 ; mask off note2
ori r16,$04 ; set note2 trigger
sts note_amp_state,r16 ; save note amp state
ori r25,$02
sts note_scheduler,r25 ; set note1 as taken
ret

playnote3: ; else set note rising if stealing (done above)

lds zl,note_voice_temp ; fetch voice
lds r17,note_value_temp ; fetch frequency
sts note3_voice,zl ; store voicing information
mov r22,r17 ; load note1 frequency register
andi zl,$18
lsr zl
lsr zl
ori zl,$40 ; set to lookup table position
ldi zh,$08 ; prep fetch pointer
ld r16,z ; fetch attack
sts note3_attack,r16 ; set attack
inc zl
ld r16,z ; fetch decay
sts note3_decay,r16 ; set decay
lds r16,note_amp_state ; fetch note amp state
andi r16,$cf ; mask off note3
ori r16,$10 ; set note3 trigger
sts note_amp_state,r16 ; save note amp state
ori r25,$04
sts note_scheduler,r25 ; set note1 as taken
ret

playnote4: ; else set note rising if stealing (done above)

lds zl,note_voice_temp ; fetch voice
lds r17,note_value_temp ; fetch frequency
sts note4_voice,zl ; store voicing information
mov r23,r17 ; load note1 frequency register
andi zl,$18
lsr zl
lsr zl
ori zl,$40 ; set to lookup table position
ldi zh,$08 ; prep fetch pointer
ld r16,z ; fetch attack
sts note4_attack,r16 ; set attack
inc zl
ld r16,z ; fetch decay
sts note4_decay,r16 ; set decay
lds r16,note_amp_state ; fetch note amp state
andi r16,$3f ; mask off note4
ori r16,$40 ; set note4 trigger
sts note_amp_state,r16 ; save note amp state
ori r25,$08
sts note_scheduler,r25 ; set note4 as taken
ret



