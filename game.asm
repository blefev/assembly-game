%include "/usr/share/csc314/asm_io.inc"


; how to represent everything
%define WALL_CHAR '#'

; the size of the game screen in characters
%define HEIGHT 22
%define WIDTH 70

; the player starting position.
; top left is considered (0,0)
%define STARTX 35
%define STARTY 20

; these keys do things
%define EXITCHAR 'x'
%define UPCHAR 'w'
%define LEFTCHAR 'a'
%define DOWNCHAR 's'
%define RIGHTCHAR 'd'


segment .data


	player_char	db	'^'

	;maps
	map_one	db	'map1.map',0
	map_two db	'map2.map',0
	map_three db	'map3.map',0
	map_four db 	'map4.map',0
	map_five db	'map5.map',0
	map_six db	'map6.map',0


	bg	db	1Bh,"[48;5;234m",0
	player_color	db	1Bh,"[1;38;5;202m",0
	portal_color	db	1Bh,"[48;5;17m",1Bh,"[38;5;20m",0
	ground_color	db	1Bh,"[48;5;234m",1Bh,"[38;5;65m",0
	water_color	db	1Bh,"[38;5;45m",0
	water_color_bg	db	1Bh,"[48;5;27m",0
	terrain_color	db	1Bh,"[38;5;130m",0
	terrain_color_hi db	1Bh,"[38;5;136m",0
	structure_color	db	1Bh,"[38;5;215m",0
	roof_color	db	1Bh,"[38;5;214m",0
	doorway_color	db	1Bh,"[38;5;52m",0
	wall_color	db	1Bh,"[38;5;23m",0
	button_color	db	1Bh,"[38;5;34m",0
	
	blink	db	1Bh,"[5m",0

	yellow	db	1Bh,"[33m",0
	blue	db	1Bh,"[34m",0
	brown	db	1Bh,"[38;5;94m",0

	reset	db	1Bh,"[0m",0

	; used to fopen() the board file defined above
	board_file			db 'map1',0

	; used to change the terminal mode
	mode_r				db "r",0
	raw_mode_on_cmd		db "stty raw -echo",0
	raw_mode_off_cmd	db "stty -raw echo",0

	; called by system() to clear/refresh the screen
	clear_screen_cmd	db "clear",0

	; things the program will print

	help_str			db 13,10,"Controls: ", \
							UPCHAR,"=UP / ", \
							LEFTCHAR,"=LEFT / ", \
							DOWNCHAR,"=DOWN / ", \
							RIGHTCHAR,"=RIGHT / ", \
							EXITCHAR,"=EXIT", \
							13,10,10,0
	

segment .bss

	; which map?
	current_map	resb	1

	; this array stores the current rendered gameboard (HxW)
	board	resb	(HEIGHT * WIDTH)


	; these variables store the current player position
	xpos	resd	1
	ypos	resd	1

segment .text

	global	asm_main
	extern	system
	extern	putchar
	extern	getchar
	extern	printf
	extern	fopen
	extern	fread
	extern	fgetc
	extern	fclose

asm_main:
	enter	0,0
	pusha
	;***************CODE STARTS HERE***************************

	; put the terminal in raw mode so the game works nicely
	call	raw_mode_on

	; read the game board file into the global variable
	push	board_file
	call	init_board
	add	esp, 4
	; Set current map
	mov	BYTE [current_map], 1

	; set the player at the proper start position
	mov		DWORD [xpos], STARTX
	mov		DWORD [ypos], STARTY


	; the game happens in this loop
	; the steps are...
	;   1. render (draw) the current board
	;   2. get a character from the user
	;	3. store current xpos,ypos in esi,edi
	;	4. update xpos,ypos based on character from user
	;	5. check what's in the buffer (board) at new xpos,ypos
	;	6. if it's a wall, reset xpos,ypos to saved esi,edi
	;	7. otherwise, just continue! (xpos,ypos are ok)
	game_loop:

		; draw the game board
		call	render

		; get an action from the user
		call	getchar

		; store the current position
		; we will test if the new position is legal
		; if not, we will restore these
		mov		esi, [xpos]
		mov		edi, [ypos]

		; choose what to do
		cmp		eax, EXITCHAR
		je		game_loop_end
		cmp		eax, UPCHAR
		je 		move_up
		cmp		eax, LEFTCHAR
		je		move_left
		cmp		eax, DOWNCHAR
		je		move_down
		cmp		eax, RIGHTCHAR
		je		move_right
		jmp		input_end			; or just do nothing

		; move the player according to the input character
		move_up:
			mov	BYTE [player_char], '^'
			dec		DWORD [ypos]
			jmp		input_end
		move_left:
			mov	BYTE [player_char], '<'
			dec		DWORD [xpos]
			jmp		input_end
		move_down:
			mov	BYTE [player_char], 'v' 
			inc		DWORD [ypos]
			jmp		input_end
		move_right:
			mov	BYTE [player_char], '>'
			inc		DWORD [xpos]
		input_end:

		; (W * y) + x = pos

		; compare the current position to the wall character
		mov		eax, WIDTH
		mul		DWORD [ypos]
		add		eax, [xpos]
		lea		eax, [board + eax]

		cmp	BYTE [eax], '.'
		je	valid_move
		
		cmp	BYTE [eax], ' '
		je	valid_move

		cmp	BYTE [eax], '['
		je	valid_move

		cmp	BYTE [eax], ']'
		je	valid_move

		cmp	BYTE [eax], '%'
		je	continue
		cmp	BYTE [eax], '@'
		jne	invalid_move
		continue:

		call	change_map
		cmp	BYTE[current_map], 2
		jne	valid_move
		mov	DWORD [xpos], 33
		mov	DWORD [ypos], 20
		jmp	valid_move
		invalid_move:

			; that was an invalid move, reset
			mov		DWORD [xpos], esi
			mov		DWORD [ypos], edi
		valid_move:

	jmp		game_loop
	game_loop_end:

	; restore old terminal functionality
	call raw_mode_off

	;***************CODE ENDS HERE*****************************
	popa
	mov		eax, 0
	leave
	ret

; === FUNCTION ===
raw_mode_on:

	push	ebp
	mov		ebp, esp

	push	raw_mode_on_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
raw_mode_off:

	push	ebp
	mov		ebp, esp

	push	raw_mode_off_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
init_board:

	push	ebp
	mov		ebp, esp

	; FILE* and loop counter
	; ebp-4, ebp-8
	sub		esp, 8

	; open the file
	push	mode_r
	push	DWORD [ebp+8]
	call	fopen
	add		esp, 8
	mov		DWORD [ebp-4], eax

	; read the file data into the global buffer
	; line-by-line so we can ignore the newline characters
	mov		DWORD [ebp-8], 0
	read_loop:
	cmp		DWORD [ebp-8], HEIGHT
	je		read_loop_end

		debug:
		; find the offset (WIDTH * counter)
		mov		eax, WIDTH
		mul		DWORD [ebp-8]
		lea		ebx, [board + eax]

		; read the bytes into the buffer
		push	DWORD [ebp-4]
		push	WIDTH
		push	1
		push	ebx
		call	fread
		add		esp, 16

		; slurp up the newline
		push	DWORD [ebp-4]
		call	fgetc
		add		esp, 4

	inc		DWORD [ebp-8]
	jmp		read_loop
	read_loop_end:

	; close the open file handle
	push	DWORD [ebp-4]
	call	fclose
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
render:

	push	ebp
	mov		ebp, esp

	; two ints, for two loop counters
	; ebp-4, ebp-8
	sub		esp, 8

	; clear the screen
	push	clear_screen_cmd
	call	system
	add		esp, 4

	; print the help information
	push	help_str
	call	printf
	add		esp, 4

	; outside loop by height
	; i.e. for(c=0; c<height; c++)
	mov		DWORD [ebp-4], 0
	y_loop_start:
	cmp		DWORD [ebp-4], HEIGHT
	je		y_loop_end

		; inside loop by width
		; i.e. for(c=0; c<width; c++)
		mov		DWORD [ebp-8], 0
		x_loop_start:
		cmp		DWORD [ebp-8], WIDTH
		je 		x_loop_end

			; check if (xpos,ypos)=(x,y)
			mov		eax, [xpos]
			cmp		eax, DWORD [ebp-8]
			jne		print_board
			mov		eax, [ypos]
			cmp		eax, DWORD [ebp-4]
			jne		print_board
				; if both were equal, print the player

	; TODO TODO TODO PRINT PLAYER 
				
				push	player_color	
				call	printf
				add	esp, 4

				push	bg
				call	printf
				add	esp,4
				
				xor	edx, edx
				mov	dl, BYTE [player_char]
				push	edx		
				call	putchar
				add	esp, 4

				push	reset	
				call	printf
				add	esp, 4

				jmp		player_end
			print_board:
				; otherwise print whatever's in the buffer
				push	bg
				call	printf
				add	esp, 4

				mov		eax, [ebp-4]
				mov		ebx, WIDTH
				mul		ebx
				add		eax, [ebp-8]
				mov		ebx, 0
				mov		bl, BYTE [board + eax]
				push		ebx
				call	set_tile_color
				
			print_end:

			call	putchar
			add		esp, 4

			push	reset
			call	printf
			add	esp, 4
			player_end:

		inc		DWORD [ebp-8]
		jmp		x_loop_start
		x_loop_end:

		; write a carriage return (necessary when in raw mode)
		push	0x0d
		call 	putchar
		add		esp, 4

		; write a newline
		push	0x0a
		call	putchar
		add		esp, 4

	inc		DWORD [ebp-4]
	jmp		y_loop_start
	y_loop_end:

	cmp	BYTE[current_map], 6
	je	game_loop_end

	mov		esp, ebp
	pop		ebp
	ret

set_tile_color:

	cmp	bl, '~' 
	je	water
	
	cmp	bl, '@'
	je	portal	
	
	cmp	bl, '='
	je	log	

	cmp	bl, '.'
	je	ground

	cmp	bl, '"'
	je	terrain

	cmp	bl, '`'
	je	terrain_hi

	cmp	bl, '|'
	je	structure

	cmp	bl, '/'
	je	roof

	cmp	bl, '\'
	je	roof

	cmp	bl, '['
	je	doorway
	cmp	bl, ']'
	je	doorway

	cmp	bl, '*'
	je	light

	cmp	bl, '#'
	je	wall

	cmp	bl, '%'
	je	button

	set_tile_color_end:
	ret


	button:
		push	button_color
		call	printf
		add	esp, 4
		jmp	set_tile_color_end
		

	wall:
		push	wall_color
		call	printf
		add	esp, 4
		jmp	set_tile_color_end	

	light:
		push	yellow
		call	printf
		add	esp, 4
		jmp	set_tile_color_end

	water:
		push	water_color
		call	printf
		add	esp, 4

		push	water_color_bg
		call	printf
		add	esp, 4

		jmp	set_tile_color_end
	
	portal:

		
		push	portal_color
		call	printf
		add	esp, 4
		jmp	set_tile_color_end

	log:
		push	brown
		call	printf
		add	esp,4
		jmp	set_tile_color_end

	ground:

		push	ground_color
		call	printf
		add	esp,4
		jmp	set_tile_color_end
	
	terrain:
		push	terrain_color
		call	printf
		add	esp,4
		jmp	set_tile_color_end

	terrain_hi:
		push	terrain_color_hi
		call	printf
		add	esp,4
		jmp	set_tile_color_end

	structure:
		push	structure_color
		call	printf
		add	esp,4
		jmp	set_tile_color_end
	
	roof:
		push	roof_color
		call	printf
		add	esp,4
		jmp	set_tile_color_end
		
	doorway:
		push	doorway_color
		call	printf
		add	esp,4
		jmp	set_tile_color_end		

change_map:

	push	ebp
	mov	ebp, esp

	; clear the screen
	push	clear_screen_cmd
	call	system
	add	esp, 4

	; What map to print?
	cmp	BYTE [current_map], 1
	je	map1
	cmp	BYTE [current_map], 2
	je	map2
	cmp	BYTE [current_map], 3
	je	map3
	cmp	BYTE [current_map], 4
	je	map4
	cmp	BYTE [current_map], 5
	je	map5

	map_next:
	call	init_board
	add	esp, 4


	
	mov	esp, ebp
	pop	ebp
	
	ret

	; MAP -> DOOR
	map1:

		mov 	DWORD[xpos], 21
		mov	DWORD[xpos], 33

		mov	BYTE[current_map], 2
		push	map_two
		jmp	map_next

	map2:
		mov	BYTE[current_map], 3
		push	map_three
		jmp	map_next

	map3:
		mov	BYTE[current_map], 4
		push	map_four
		jmp	map_next
	map4:
		mov	BYTE[current_map], 5
		push	map_five
		jmp	map_next
	map5:
		mov	BYTE[current_map], 6
		push	map_six
		jmp	map_next
