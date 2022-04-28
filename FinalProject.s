                area project, code, readonly
                export __main
                    
                ; TODO
                ;   * Getting Seed Value (Systick timer?)
                ;   * Game Over Screen
                ;       - Input for restart?
                ;       - Show score?
                ;   * Lives
                ;   * Difficulty Levels
                ;       - Different length words (CHANGE LINES 192 and 258)

CMD             equ 0x80 ; EN=1 RW=0 RS=0
DATA            equ 0xA0 ; EN=1 RW=0 RS=1
EN              equ 0x80

TITLE           dcb "Hangman"
DIFF            dcb "Easy Med Hard"
BANK1           dcb "CRUEL DUMMY CLUMP HONEY SHORT HORSE BALLS ZESTY XRAYS QUOTA SHOWN HEIST MONEY BLOOD PANDA BRAWL"
BANK2			dcb "CUPCAKE FACTION BALLETS GENERIC CONFIDE INCENSE ARRIVAL CLASSIC CRACKER ABANDON HABITAT ICEBERG MACARON MERMAID UKULELE VACCINE"
BANK3			dcb "ABDOMINAL OBJECTIVE ZOMBIFIED ZOOKEEPER YOUNGSTER ULTIMATUM URINATION QUADRATIC QUOTATION PAINTBALL PACKAGING LABYRINTH JELLYBEAN JAILBREAK IDENTICAL FICTIONAL"
HEART           dcb 0x00, 0x0A, 0x1F, 0x1F, 0x1F, 0x0E, 0x04, 0x00
HALFHEART       dcb 0x00, 0x08, 0x1C, 0x1C, 0x1C, 0x0C, 0x04, 0x00
WIN             dcb "Congratulations"
LOSE            dcb "Try Again"

LEN             rn r12
ANS             rn r11
GUESS           rn r10
CORRECT         rn r9
FLAGS           rn r8
LIVES			rn r7

__main          proc
startover		ldr r3, =0xE000E000 ; Systick Timer for PRNG
				ldr r4, =0x2DC6C0
				str r4, [r3, #0x14] ; STRVR
				mov r4, #0x04
				str r4, [r3, #0x10] ; STCSR
				orr r4, #0x01
				str r4, [r3, #0x10] ; Start Timer
				bl delay
				ldr r5, [r3, #0x18] ; STCVR
				push {r5}
                bl LCDInit
				bl Menu
                bl Game
                bl Gameover
newbtn       	ldrb r2, [r0] ; load input
                tst r2, #0x0D ; any button
                beq newbtn
				b startover
                endp
                    
LCDInit         function
                ldr r0, =0x40004C20
                ldr r1, =0x40004C21
                mov r2, #0xE0 ; 3.7, 3.6, 3.5 outputs
                strb r2, [r0, #0x04]
                mov r2, #0x0D ; REN for 3.3, 3.2, 3.0
                strb r2, [r0, #0x06]
                mov r2, #00 ; Pull Down for 3.3, 3.2, 3.0
                strb r2, [r0, #0x02]
                mov r2, #0xFF ; Port 4 output
                strb r2, [r1, #0x04]
                push {lr}
                mov r2, #0x38 ; 16x2 matrix
                bl LCDCommand
                mov r2, #0x0C ; display on, cursor off
                bl LCDCommand
                mov r2, #0x01 ; clear display
                bl LCDCommand
                bl LifeSymbol ; write custom symbols to cgram
                pop {lr}
                bx lr
                endp
                    
LCDCommand      function
                push {r4, r5}
                mov r4, #CMD
                strb r4, [r0, #0x02]
                strb r2, [r1, #0x02]
                push {lr}
                bl delay
                pop {lr}
                mov r4, #00
                strb r4, [r0, #0x02]
				pop {r4, r5}
                bx lr
                endp
                    
LCDData         function
                push {r4, r5}
                mov r4, #DATA
                strb r4, [r0, #0x02]
                strb r3, [r1, #0x02]
                push {lr}
                bl delay
                pop {lr}
                mov r4, #0x02
                strb r4, [r0, #0x02]
				pop {r4, r5}
                bx lr
                endp
                    
Selector        function
                push {lr}
                mov r2, #0x8F ; (0,15) ; selector position
                bl LCDCommand
				bl First ; first available letter
				mov r3, r4
                bl LCDData
input           mov r2, #0x8F ; (0,15) ; selector position
                bl LCDCommand
                ldrb r2, [r0] ; load input
                tst r2, #0x08 ; up/right
                bne inc
                tst r2, #0x04 ; down/left
                bne dec
                tst r2, #0x01 ; enter
                beq input
                mov GUESS, r3
                pop {lr}
                bx lr
inc             bl First ; update first available letter
				cmp r3, r5 ; loopback
				bne forward
				mov r3, r4
updateinc       bl LCDData
                mov r6, #00
pause           bl delay
                add r6, #1
                cmp r6, #16 ; ~200 ms
                bne pause
                b input
forward         sub r6, r3, #'A'
				add r6, #1
nextlet         mov r5, #1
				lsl r5, r5, r6
				tst FLAGS, r5
				addne r3, r6, #'A'
				addeq r6, #1
				beq nextlet
				b updateinc
dec             bl Last ; update last available letter
				cmp r3, r4 ; loopback
				bne backward
				mov r3, r5
updatedec       bl LCDData
                mov r6, #00
pause2          bl delay
                add r6, #1
                cmp r6, #16 ; ~200 ms
                bne pause2
                b input
backward        sub r6, r3, #'A'
				sub r6, #1
prevlet         mov r5, #1
				lsl r5, r5, r6
				tst FLAGS, r5
				addne r3, r6, #'A'
				subeq r6, #1
				beq prevlet
				b updatedec
                endp

First           function
				push {r5}
				mov r5, FLAGS
				mov r4, #0
firstlet        tst r5, #0x01 ; A enable bit
				lsreq r5, #1 ; count shifts until bit 0 is high
				addeq r4, #1
				beq firstlet
				add r4, r4, #'A' ; add count to A to get letter
				pop {r5}
				bx lr
				endp
                
Last          	function
				push {r4}
				mov r4, FLAGS
				mov r5, #0
lastlet         tst r4, #0x2000000 ; Z enable bit
				lsleq r4, #1 ; count shifts until bit 25 is high
				addeq r5, #1
				beq lastlet
				mov r4, #'Z'
				sub r5, r4, r5 ; subtract count from Z to get letter
				pop {r4}
				bx lr
				endp

Guess           function
                push {lr}
				mov r6, CORRECT
                mov r4, #0
letterloop   	mov r2, #0x0F ; find first blank again
                sub r2, LEN
                lsr r2, #1
                add r2, #0xC0
				add r2, #1
				ldrb r3, [ANS, r4]
                cmp r3, GUESS ; compare letter to guess
                beq replace ; rewrite letter
                add r4, #1
                cmp LEN, r4
                bne letterloop
finishguess     sub r4, GUESS, #'A'
				mov r5, #1
				lsl r5, r4
				bic FLAGS, r5 ; remove the guess letter from selection
				cmp CORRECT, r6 ; guess was wrong -> lose life
				subeq LIVES, #1
				pop {lr}
                cmp CORRECT, LEN ; 
				bleq longdelay
                moveq r6, #1
				beq gameend
				cmp LIVES, #0
				moveq r6, #0
				bxne lr
				mov r2, #0x0F ; max length
                sub r2, LEN ; padding
                lsr r2, #1 ; floor the value
                add r2, #0xC0 ; location to write
				add r2, #1
				bl LCDCommand
                mov r5, #00
ansloop         ldrb r3, [ANS, r5]
				bl LCDData
                add r5, #1
                cmp r5, LEN
                bne ansloop
				bl longdelay
gameend         pop {lr}
                bx lr
                
replace         add CORRECT, #1 ; increment correct letters
				add r2, r4 ; positional offset
                bl LCDCommand
                bl LCDData ; writes guess letter
				add r4, #1
				cmp LEN, r4
                bne letterloop
				b finishguess
                endp
                    
Menu            function
                push {lr}
                mov r2, #0x01 ; clear
                bl LCDCommand
                mov r5, #0 ; counter for word
                ldr r2, =TITLE
titleloop       ldrb r3, [r2, r5] ; write title
                bl LCDData
                add r5, #1
                cmp r5, #7
                bne titleloop
                mov r2, #0xC0 ; next line
                bl LCDCommand
                mov r5, #0
                ldr r2, =DIFF
diffloop        ldrb r3, [r2, r5] ; write difficulty
                bl LCDData
                add r5, #1
                cmp r5, #13
                bne diffloop
startbtn        ldrb r2, [r0] ; load input
                tst r2, #0x04 ; easy
				beq hard
				mov LEN, #5
				b startgame
hard			tst r2, #0x08 ; hard
				beq medium
				mov LEN, #9
				b startgame
medium			tst r2, #0x01 ; medium
				beq startbtn
				mov LEN, #7
startgame		pop {lr}
                bx lr
                endp

Game            function
				pop {r5} ; Systick start val
                push {lr}
				mov CORRECT, #0 ; reset # correct guesses
				mov LIVES, #10 ; sets lives
				ldr r8, =0x3FFFFFF ; 26 bits for enabling/disabling letters
                mov r2, #0x01 ; clear
                bl LCDCommand
; following comments print the word
;                mov r2, #0x0F ; max length
;                sub r2, LEN ; padding
;                lsr r2, #1 ; floor the value
;                add r2, #0x80 ; location to write
;				 add r2, #1
;                bl LCDCommand
                bl WordRNG ; get random word
;                mov r5, #00
;loop            ldrb r3, [ANS, r5]
;                bl LCDData
;                add r5, #1
;                cmp r5, LEN
;                bne loop
				mov r4, #0
lives           add r2, r4, #0x80 ; first column
                bl LCDCommand
                mov r3, #0x00 ; write hearts
                bl LCDData
				add r4, #1
				cmp r4, #5
				bne lives
                mov r2, #0x0F
                sub r2, LEN
                lsr r2, #1
                add r2, #0xC0
				add r2, #1 ; center blanks
                bl LCDCommand
                mov r5, #0
blank           mov r3, #'_' ; write blanks
				bl LCDData
                add r5, #1
                cmp r5, LEN
                bne blank
next            bl Selector
                bl Guess
				cmp LIVES, #10 ; full lives -> skip life editing
				beq inputdelay
				lsr r6, LIVES, #1 ; # full hearts
				add r2, r6, #0x80 ; position to overwrite
				bl LCDCommand
				tst LIVES, #0x01 ; odd/even lives
				bne half
				mov r3, #' '
				bl LCDData
inputdelay		bl longdelay
                b next
half			mov r3, #0x01 ; half heart
				bl LCDData
				b inputdelay
				ltorg
                endp

Gameover        function
                push {lr}
                mov r2, #0x01   ; clear board
                bl LCDCommand
				cmp r6, #1 ; win/lose
				bne lose
win             mov r5, #0
                ldr r7, =WIN
winloop         ldrb r3, [r7, r5] ; print congrats
                bl LCDData
                add r5, #1
                cmp r5, #15
                bne winloop
				b stop
lose			mov r5, #0
				ldr r7, =LOSE
loseloop		ldrb r3, [r7, r5] ; print try again
				bl LCDData
				add r5, #1
				cmp r5, #9
				bne loseloop
stop            pop {lr}
				bx lr
                endp

WordRNG         function
                ; implementation of xorshift prng for values 0 to 15, r2 is seed value
				ldr r3, =0xE000E000
				mov r4, #0x04
				str r4, [r3, #0x10] ; Stop Timer
				ldr r6, [r3, #0x18]
				sub r2, r5, r6 ; time difference is seed value
                eor r2, r2, lsl #13
                eor r2, r2, lsr #17
                eor r2, r2, lsl #5
				and r2, #0x0F ; scale output to [0,16)
				cmp LEN, #7
				ldreq r6, =BANK2 ; medium
				ldrlo r6, =BANK1 ; easy
				ldrhi r6, =BANK3 ; hard
                push {LEN}
                add LEN, #1
                mul r2, LEN
                pop {LEN}
                add ANS, r6, r2 ; stores offset for chosen word
                bx lr
                endp
                    
LifeSymbol      function ; saves full/half heart symbol to CGRAM with character code #0x00, #0x08 for full heart and #0x01, #0x09 for half heart
                push {lr}
                ldr r4, =HEART ; pixel by pixel drawing
				ldr r5, =HALFHEART
                mov r6, #00 ; counter for CGRAM adresses (lines/rows)
nextaddr        add r2, r6, #0x40 ; start writing to CGRAM #0x00
				bl LCDCommand
                ldrb r3, [r4, r6]
                bl LCDData
				add r2, r6, #0x48 ; start writing to CGRAM #0x01
				bl LCDCommand
				ldrb r3, [r5, r6]
				bl LCDData
                add r6, #1
                cmp r6, #8 ; max 8 lines
                bne nextaddr
                pop {lr}
                bx lr
                endp

delay           function ; very short delay
				push {r4, r5}
                mov r5, #50
outer           mov r4, #0xFF
inner           subs r4, #1
                bne inner
                subs r5, #1
                bne outer
				pop {r4, r5}
                bx lr
                endp
					
longdelay		function ; ~900 ms
				push {lr}
				mov r6, #0
enddelay	    bl delay
				add r6, #1
				cmp r6, #75
				bne enddelay
				pop {lr}
				bx lr
				endp
                    
                end
