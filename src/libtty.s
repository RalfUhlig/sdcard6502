; TTY interfacing

; KIM routines
OUTCH  = $1EA0 
PRTBYT = $1E3B
PRCRLF = $1E2F

TMPY = $30

tty_init:
  jmp print_crlf
  
print_char:
  sty TMPY
  jsr OUTCH
  ldy TMPY
  rts
  
print_hex:
  sty TMPY
  jsr PRTBYT
  ldy TMPY
  rts

print_crlf:
  sty TMPY
  jsr PRCRLF
  ldy TMPY
  rts

