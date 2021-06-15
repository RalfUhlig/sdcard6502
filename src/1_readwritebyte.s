; KIM 6532 Aux I/O
PORTB = $1702
DDRB = $1703

; KIM routines
OUTCH  = $1EA0 
PRTBYT = $1E3B
PRCRLF = $1E2F

SD_CS   = %00010000
SD_SCK  = %00001000
SD_MOSI = %00000100
SD_MISO = %00000010

PORTB_OUTPUTPINS = SD_CS | SD_SCK | SD_MOSI

  .org $0200

reset:
  cld
  ldx #$ff
  txs

  lda #PORTB_OUTPUTPINS   ; Set various pins on port B to output
  sta DDRB

  jsr PRCRLF

  ; Let the SD card boot up, by pumping the clock with SD CS disabled
  lda #'I'
  jsr print_char

  ; We need to apply around 80 clock pulses with CS and MOSI high.
  ; Normally MOSI does not matter when CS is high, but the card is
  ; not yet is SPI mode, and in this non-SPI state it does care.

  lda #SD_CS | SD_MOSI
  ldx #160               ; toggle the clock 160 times, so 80 low-high transitions
.preinitloop:
  eor #SD_SCK
  sta PORTB
  dex
  bne .preinitloop
  
  ; Read a byte from the card, expecting $ff as no commands have been sent
  jsr sd_readbyte
  jsr print_hex

.cmd0
  ; GO_IDLE_STATE - resets card to idle state
  ; This also puts the card in SPI mode.
  ; Unlike most commands, the CRC is checked.

  lda #'c'
  jsr print_char
  lda #$00
  jsr print_hex

  ; Supply some clock cycles before and after activating CS to ensure the sd card recognizes the change of CS.
  ; See https://electronics.stackexchange.com/questions/303745/sd-card-initialization-problem-cmd8-wrong-response
  lda #$ff
  jsr sd_writebyte
  lda #SD_MOSI           ; pull CS low to begin command
  sta PORTB
  lda #$ff
  jsr sd_writebyte

  ; CMD0, data 00000000, crc 95
  lda #$40
  jsr sd_writebyte
  lda #$00
  jsr sd_writebyte
  lda #$00
  jsr sd_writebyte
  lda #$00
  jsr sd_writebyte
  lda #$00
  jsr sd_writebyte
  lda #$95
  jsr sd_writebyte

  ; Read response and print it - should be $01 (not initialized)
  jsr sd_waitresult
  pha
  jsr print_hex

  ; Supply some clock cycles before and after deactivating CS to ensure the sd card recognizes the change of CS.
  ; See https://electronics.stackexchange.com/questions/303745/sd-card-initialization-problem-cmd8-wrong-response
  lda #$ff
  jsr sd_writebyte
  lda #SD_CS | SD_MOSI   ; set CS high again
  sta PORTB
  lda #$ff
  jsr sd_writebyte

  ; Expect status response $01 (not initialized)
  pla
  cmp #$01
  bne .initfailed

  lda #'Y'
  jsr print_char


.loop:
.stop:
  brk


.initfailed
  lda #'X'
  jsr print_char
  jmp .loop


sd_readbyte:
  ; Enable the card and tick the clock 8 times with MOSI high, 
  ; capturing bits from MISO and returning them

  ldx #8                      ; we'll read 8 bits
.loop:

  lda #SD_MOSI                ; enable card (CS low), set MOSI (resting state), SCK low
  sta PORTB

  lda #SD_MOSI | SD_SCK       ; toggle the clock high
  sta PORTB

  lda PORTB                   ; read next bit
  and #SD_MISO

  clc                         ; default to clearing the bottom bit
  beq .bitnotset              ; unless MISO was set
  sec                         ; in which case get ready to set the bottom bit
.bitnotset:

  tya                         ; transfer partial result from Y
  rol                         ; rotate carry bit into read result
  tay                         ; save partial result back to Y

  dex                         ; decrement counter
  bne .loop                   ; loop if we need to read more bits

  rts


sd_writebyte:
  ; Tick the clock 8 times with descending bits on MOSI
  ; SD communication is mostly half-duplex so we ignore anything it sends back here

  ldx #8                      ; send 8 bits

.loop:
  asl                         ; shift next bit into carry
  tay                         ; save remaining bits for later

  lda #0
  bcc .sendbit                ; if carry clear, do not set MOSI for this bit
  ora #SD_MOSI

.sendbit:
  sta PORTB                   ; set MOSI (or not) first with SCK low
  eor #SD_SCK
  sta PORTB                   ; raise SCK keeping MOSI the same, to send the bit

  tya                         ; restore remaining bits to send

  dex
  bne .loop                   ; loop if there are more bits to send

  rts


sd_waitresult:
  ; Wait for the SD card to return something other than $ff
  jsr sd_readbyte
  cmp #$ff
  beq sd_waitresult
  rts

print_char:
  jmp OUTCH

print_hex:
  jmp PRTBYT
