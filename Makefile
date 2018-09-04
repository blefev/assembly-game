NAME=game

all: game

clean:
	rm -rf game game.o

game: game.asm
	nasm -f elf game.asm
	gcc -g -m32 -o game game.o # C Driver /usr/share/csc314/driver.c /usr/share/csc314/asm_io.o
