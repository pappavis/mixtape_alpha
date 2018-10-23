; mixtape_defs.inc
; list of definitions

.equ pad1_state = $0800
.equ pad2_state = $0801
.equ pad1_prev = $0802
.equ pad2_prev = $0803
.equ lfo_lsb = $0804
.equ lfo_msb = $0805
.equ lfo_value = $0806
.equ led_blink = $0807
.equ note_counter = $0808
.equ pattern_top_lsb = $0809
.equ pattern_top_msb = $080a
.equ note_counter_top = $080b
.equ note_subcounter = $080c
.equ note1_amp = $080d
.equ note2_amp = $080e
.equ note3_amp = $080f
.equ note4_amp = $0810
.equ note1_voice = $0811
.equ note2_voice = $0812
.equ note3_voice = $0813
.equ note4_voice = $0814
.equ led_blink_timer = $0815
.equ note_amp_state = $0816
.equ note_trigger = $0817
.equ last_note_time = $0818
.equ pattern_backup_lsb = $0819
.equ pattern_backup_msb = $081a
.equ fm_value = $081b
.equ led_flip = $081c
.equ note_scheduler = $081d
.equ note_voice_temp = $081e
.equ note_value_temp = $081f
;note table placed at $0820 - $083f
;attack/decay table at $0840 - $0847
.equ note1_attack = $0848
.equ note2_attack = $0849
.equ note3_attack = $084a
.equ note4_attack = $084b
.equ note1_decay = $084c
.equ note2_decay = $084d
.equ note3_decay = $084e
.equ note4_decay = $084f
;button datatable at $0850 - $085f
.equ buttondata_pointer = $0861
.equ buttondata_counter = $0862
.equ slider_high = $0863
.equ slider_low = $0864
