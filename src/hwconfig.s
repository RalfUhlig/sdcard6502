PORTB = $1702
DDRB = $1703

SD_CS   = %00010000
SD_SCK  = %00001000
SD_MOSI = %00000100
SD_MISO = %00000010

PORTB_OUTPUTPINS = SD_CS | SD_SCK | SD_MOSI

via_init:
  lda #PORTB_OUTPUTPINS   ; Set various pins on port A to output
  sta DDRB
  rts

