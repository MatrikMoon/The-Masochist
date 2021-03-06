; include sceen output helper funtions
%include "screen.asm"
%include "loader.asm"

%define KEYB_LEN 24

extern printf

section .data
	new_line:	db  0xA
	deviceP_file:	db './input_device', 0
	logo:		db './start_screen', 0
	lvl:		db './lvl_map', 0
	src0:		db './src_code_blob', 0
	world_file:	db './world_res', 0
	world_len:	equ 6000
	world_w:	db 120
	testb:		db '1234', 0
	timeval:	
		t_sec 	dd 0
		t_usec 	dd 0
	player:		db '#####', 0
	target:		db '***', 0
	fmtStr:		db "Score: %d", 0xA, 0
	start_str:	db "Game Loader...", 0xA, "Type help for options.", 0xA, 0
	start_str_len:	equ $ - start_str
	help_d:		db "Controls: ", 0xA, "Paddle movement: w, e, r, u, i, o | try to hit the *'s", 0xA, "Type run to begin game", 0xA, "Type about for game info", 0xA, "Type exit to quit", 0xA, 0xA, 0
	help_d_len:	equ $ - help_d
	about_d:	db "The masochist is a timing based terminal game", 0xA, "written for linux in 32 bit asm", 0xA, 0xA, 0
	about_d_len:	equ $ - about_d
	end_p:		db "Press enter to restart game", 0xA, 0
	end_p_len:	equ $ - end_p
	prompt:		db "> ", 0
	run_game:	db "run", 0
	help_p:		db "help", 0
	about_p:	db "about", 0
	exit_p:		db "exit", 0
	loading_g	db "Loading game...", 0xA, 0
	loading_g_len	equ $ - loading_g
	; Keys usr can press to move paddle
	keys		db 0x11, 0x12, 0x13, 0x16, 0x17, 0x18
	p_pos		db 4, 26, 47, 68, 89, 109

section .bss
	screen:		resb world_len
	world:		resb world_len
	device_path:	resb 256
	buff:		resb 32768
	lvl_buff:	resb 2048
	playerX:	resb 8
	playerY:	resb 8
	score:		resb 8
	act_tar:	resb 4
	render_cyc:	resb 4
	spawn_cyc:	resb 4
	key_buf:	resb 512
	fd_in:		resb 8
	key_in:		resb 8
	key:		resb 8
	usr_in:		resb 128

; REMINDER the six registers used to store arugments of Linux kernal 
; sys calls are EBX, ECX, EDX, ESI, EDI, and EBP
; sys call refs on syscalls.kernelgrok.com
section .text
	global main

; start game at menu
main:
	call	_clear_screen

	call	_load_device
	call	_new_line

	mov	ecx, start_str
	mov	edx, start_str_len
	call	_print_line

	jmp	restart_end

restart:
	call	_clear_screen

	mov	ecx, end_p
	mov	edx, end_p_len
	call	_print_line

	; get user input
	mov	eax, 3
	mov	ebx, 0
	mov	ecx, usr_in
	mov	edx, 128	
	int	0x80

restart_end:

; run repeating menu dialog
.start_d:

	mov	eax, dword [score]
	cmp	eax, 0
	je	.pscore_end

.print_score:	
	mov	eax, [score]
	call	_print_f

	mov	[score], dword 0

.pscore_end:

	mov	eax, 4
	mov	ebx, 1
	mov	ecx, prompt
	mov	edx, 2
	int	0x80

	; get user input
	mov	eax, 3
	mov	ebx, 0
	mov	ecx, usr_in
	mov	edx, 128	
	int	0x80

	; see if user typed run
	mov	ecx, 3
	mov	esi, usr_in
	mov	edi, run_game
	call	_n_cmp

	cmp	eax, 0
	je	_start_game

	; if user types help
	mov	ecx, 4
	mov	esi, usr_in
	mov	edi, help_p
	call	_n_cmp

	cmp	eax, 0
	je	.help

	; if user types about
	mov	ecx, 5
	mov	esi, usr_in
	mov	edi, about_p
	call	_n_cmp

	cmp	eax, 0
	je	.about

	; if user types exit
	mov	ecx, 4
	mov	esi, usr_in
	mov	edi, exit_p
	call	_n_cmp

	cmp	eax, 0
	je	_sys_exit

	jmp	.start_d
.help:
	mov	ecx, help_d
	mov	edx, help_d_len
	call	_print_line
	jmp	.start_d

.about:
	mov	ecx, about_d
	mov	edx, about_d_len
	call	_print_line
	jmp	.start_d

; Start game
_start_game:
	
	mov	[act_tar], byte 0

	mov	ecx, loading_g
	mov	edx, loading_g_len
	call	_print_line

	; a tastfull pause to build suspense 
	mov	eax, 1
	mov	ebx, 0
	call	_sleep

	; scroll source code
	call	_scroll_src

	mov	[playerX], byte 4
	mov	[playerY], byte 45

	; load resources 
	call	_load_start_screen
	call	_load_world
	call	_load_lvl
	call	_open_input

	jmp	_game_loop

; put dd in eax
_print_f:
	pusha

	push	ebp
	mov	ebp, esp
	
	push	eax
	push	dword fmtStr
	call	printf
	add	esp, 12
	mov	eax, 0

	popa
	ret

_open_input:

	pusha
	mov	eax, 5
	mov	ebx, device_path
	mov	ecx, 4000
	int	0x80

	mov	[key_in], eax
	
	mov	eax, 3
	mov	ebx, [key_in]
	mov	ecx, key_buf
	mov 	edx, 32
	int	0x80

	mov	eax, 0
	mov	ax, word [key_buf + 26]
	mov	[key], ax
	
	popa
	ret

_read_input:
	pusha	

	mov	eax, 3
	mov	ebx, [key_in]
	mov	ecx, key_buf
	mov 	edx, 32
	int	0x80

	mov	eax, 0
	mov	ax, word [key_buf + 26]
	mov	[key], ax
	
	popa
	ret


; MAIN GAME LOOP
_game_loop:

	mov	eax, 0
	mov	ebx, 5000000
	call	_sleep

	mov	eax, [render_cyc]
	add	[render_cyc], dword 1

	cmp	eax, 10
	jne	.do_keys

	; Clear and render console game screen
.render:
	mov	[render_cyc], byte 0
	call	_new_line
	mov	ecx, 7

.clear_loop:
	call	_new_line
	loop	.clear_loop

	mov	eax, [score]
	call	_print_f

	mov	eax, [spawn_cyc]
	add	[spawn_cyc], dword 1

	cmp	eax, 5
	jne	.spawn_end

.spawn:
	; spawn tagets

	mov	[spawn_cyc], byte 0

	; get number 0 - 6 from lvl file
	mov	esi, lvl_buff
	add	esi, [act_tar]
	mov	eax, 0
	mov	al, byte [esi]
	sub	al, '0'

	cmp	al, 6
	je	.rest

	cmp	al, 9
	je	restart

	; associate that number 0 - 6 with its corresponding collum 
	mov	esi, p_pos
	add	esi, eax
	mov	eax, 0
	mov	al, byte [esi]
	inc	eax

	; write target into world
	mov	edi, world
	mov	esi, target
	add	edi, 120
	add	edi, eax
	movsb

.rest:
	; increment active target
	add	[act_tar], byte 1

.spawn_end:

	call	_update_targets

	call	_render

.do_keys:
	; read user input from /dev/input/event
	call	_read_input

	; put key code into eax
	mov	eax, 0
	mov	ax, [key]

	; Apply controls

	; if ESC down exit game
	cmp	eax, 1
	je	_sys_exit			
	
	mov	ebx, 0
	mov	bl, byte [keys]
	cmp	eax, ebx
	je	.key0

	mov	ebx, 0
	mov	bl, byte [keys + 1]
	cmp	eax, ebx
	je	.key1

	mov	ebx, 0
	mov	bl, byte [keys + 2]
	cmp	eax, ebx
	je	.key2

	mov	ebx, 0
	mov	bl, byte [keys + 3]
	cmp	eax, ebx
	je	.key3

	mov	ebx, 0
	mov	bl, byte [keys + 4]
	cmp	eax, ebx
	je	.key4

	mov	ebx, 0
	mov	bl, byte [keys + 5]
	cmp	eax, ebx
	je	.key5

	jmp	.end_key_eval

.key0:
	mov	al, byte [p_pos]
	mov	[playerX], al
	jmp	.end_key_eval

.key1:
	mov	al, byte [p_pos + 1]
	mov	[playerX], al
	jmp	.end_key_eval

.key2:
	mov	al, byte [p_pos + 2]
	mov	[playerX], al
	jmp	.end_key_eval

.key3:
	mov	al, byte [p_pos + 3]
	mov	[playerX], al
	jmp	.end_key_eval

.key4:
	mov	al, byte [p_pos + 4]
	mov	[playerX], al
	jmp	.end_key_eval

.key5:
	mov	al, byte [p_pos + 5]
	mov	[playerX], al
	jmp	.end_key_eval

.end_key_eval:

	; Loop
	jmp	_game_loop

; put sec in eax, and usec in ebx	
_sleep:
	pusha
	mov	dword [t_sec], eax
	mov	dword [t_usec], ebx

	mov	eax, 0xA2
	mov	ebx, timeval
	mov	ecx, 0
	int	0x80
	popa
	ret

_sys_exit:
	mov	eax, 1
	mov	ebx, 0
	int	0x80
