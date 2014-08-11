con { timing }

  ' speed settings for power control/reduction
  ' -- use with clkset() instruction
 
  XT1_PL4  = %0_1_1_01_101

  ' program speed and terminal baud
  
  T_BAUD   = 57_600 { for terminal io }

  IR_FREQ  = 36_000 { matches receiver on DC22 badge }
  IR_BAUD  = 2400   { max supported using IR connection }
  

con { io pins }

  RX1    = 31                                                   ' programming / terminal
  TX1    = 30
  
  SDA    = 29                                                   ' eeprom / i2c
  SCL    = 28

  PAD3   = 27                                                   ' touch pads
  PAD2   = 26
  PAD1   = 25
  PAD0   = 24
  
  LED7   = 23                                                   ' leds
  LED6   = 22
  LED5   = 21
  LED4   = 20
  LED3   = 19
  LED2   = 18
  LED1   = 17
  LED0   = 16

  IR_IN  = 15                                                   ' ir input
  IR_OUT = 14                                                   ' ir output


con { io configuration }

  IS_LOW    =  0                                                
  IS_HIGH   = -1                                                

  IS_INPUT  =  0
  IS_OUTPUT = -1

con { pst formatting }

  #1, HOME, GOTOXY, #8, BKSP, TAB, LF, CLREOL, CLRDN, CR
  #14, GOTOX, GOTOY, CLS
  
obj

  term : "cryptofullduplexserial64"                             ' serial io for terminal
  irtx : "jm_sircs_tx"                                          ' SIRCS output
  irrx : "jm_sircs_rx"                                          ' SIRCS input
  prng : "jm_prng"                                              ' random #s
  tmr1 : "jm_eztimer"                                           ' asynchronous timer
  ee   : "jm_24xx512"                                           ' eeprom access
  pwm  : "jm_pwm8"                                              ' pwm for LEDs
 

var

  long  ms001                                                   ' system ticks per millisecond
  long  us001                                                   ' system ticks per microsecond

  byte rx_code
  long rx_status
  long rx_shots

  long life
  byte code


dat
        d_leds          byte    "leds: ", $00
        d_inputs        byte    "inputs: ", $00

        d_reduce        byte    "Health: ", $00

        d_irrx_begin    byte    "IR Rx Begin", $00
        d_irrx_end      byte    "IR Rx End: ", $00
        d_irtx          byte    "IR Tx: ", $00

        d_status_ir_rx  byte    "IR Rx enabled: ", $00
        d_status_ir_tx  byte    "IR Tx Count: ", $00
        


pub main | idx, last, button
           
  setup

  start_leds

  start_regen

  ir_start_rx

  repeat
    repeat
      button := read_pads
    until (button <> %0000)
      term.str(@d_inputs)
      term.bin(button,4)
      term.tx(CR)

    term.dec(life)
    term.tx(CR)
    
{   if(button == %1001)
      life := 256
      rx_status := 0
      set_leds(129)
      pause(1000)
      set_leds(0)
    else
      if(rx_status <> 1)
''      start_leds
        ir_start_rx
        pause(250)
      else
}
    ir_begin_tx
    pause(250)

''    write_status

pub setup

'' Setup badge IO and objects
'' -- set speed before starting other objects
  set_speed
  
'' -- set all leds off
  set_leds(%00000000)
  
'' -- setup term
  term.start(RX1, TX1, %0000, T_BAUD)                           ' start terminal

''-- setup IR receiver
  irrx.start(IR_IN)

''-- setup IR sender
  irtx.start(IR_OUT,IR_FREQ)

''-- 
  rx_status := 1

''-- Set devices code
  code := cnt?


var
  long regenCog
  long regenStack[32]

pub start_regen

  regenCog := cognew(begin_regen,@regenStack)

  return regenCog


dat

  ' Animation tables for LEDs
  ' -- 1st byte is number of steps in animation sequence
  ' -- each step holds pattern and hold time (ms)
  ' -- for delays > 255, duplicate pattern + delay

  Death       byte      (@Death_X - @Death) / 2 + 1
              byte      %00000000, 75
              byte      %10000001, 75
              byte      %11000011, 75
              byte      %11100111, 75 
              byte      %11111111, 75
              byte      %01111110, 75  
              byte      %00111100, 75  
              byte      %00011010, 75  
              byte      %00010100, 75
              byte      %00100100, 75
              byte      %00100010, 75
              byte      %01001010, 75  
              byte      %01010001, 75  
              byte      %10001001, 75    
  Death_X     byte      %00000000, 75
  
pub begin_regen

  repeat
    if(life < 256)
      if(life > 0)
        term.dec(life)
        term.tx(CR)
        life := (life) * 2
      else
        life := 2 
    pause(2000)


pub write_status

    term.str(@d_leds)
    term.bin(read_leds-1,8)
    term.tx("(")
    term.dec(read_leds-1)
    term.tx(")")
    term.tx(",")
    term.str(@d_status_ir_rx)
    term.dec(rx_status)
    term.tx(",")
    term.str(@d_status_ir_tx)
    term.dec(rx_shots)
    term.tx(CR)


var
  long ledcog
  long ledstack[32]

pub start_leds

  ledcog := cognew(begin_leds,@ledstack)

  return ledcog

pub begin_leds

  repeat posx
    if(life > 0)
      set_leds(life - 1)
    else
      set_leds(0)
    pause(100)

var

  long  ircog                                                   ' cog running animation
  long  irstack[32]                                             ' stack space for Spin co


pub ir_start_rx

  ircog := cognew(ir_begin_rx, @irstack)

  return ircog

pub ir_begin_rx

  life := 256

  repeat
    term.str(@d_irrx_begin)
    term.tx(CR)
    rx_code := irrx.rx
    term.str(@d_irrx_end)
    term.dec(rx_code)
    term.tx(CR)
    if(rx_code <> code)
      if(life > 0)
        run_lasertag_tx
      else
        run_animation(@Death,1)
    pause(100)

  cogstop(cogid)
  
pub ir_begin_tx

  if(life > 0)
    term.str(@d_irtx)
    term.dec(code)
    term.tx(CR)
    irtx.tx(code,12,5)

    rx_shots := rx_shots + 1


pub run_lasertag_rx

  set_leds(255)
  
pub start_lasertag_tx

  run_lasertag_tx

pub run_lasertag_tx

''  term.str(@d_reduce)
''  term.bin(read_leds-1,8)
''  term.tx("(")
''  term.dec(read_leds)
''  term.tx(")")
''  term.tx(",")
  set_leds(life-1)
  life := life / 2
''  term.bin((read_leds- 1) / 2,8)
''  term.tx("(")
''  term.dec((read_leds- 1) / 2)
''  term.tx(")")
''  term.tx("(")
''  term.dec(read_leds)
''  term.tx(")")
''  term.tx(CR)
  

pub set_speed

'' Sets badge clock speed
'' -- sets timing variables ms001 and us001
'' -- note: objects may require restart after speed change

  clkset(XT1_PL4, 20_000_000)

  waitcnt(cnt + (clkfreq / 100))                                ' wait ~10ms

  ms001 := clkfreq / 1_000                                      ' set ticks per millisecond for waitcnt
  us001 := clkfreq / 1_000_000                                  ' set ticks per microsecond for waitcnt

  
pub set_leds(pattern)

'' Sets LED pins to output and writes pattern to them
'' -- swaps LSB/MSB for correct binary output

  outa[LED0..LED7] := pattern                                   ' write pattern to LEDs
  dira[LED0..LED7] := IS_HIGH                                   ' make LED pins outputs


pub read_leds

  return life
  ''return (!ina[LED0..LED7] * -1)

  
pub read_pads

'' Reads and returns state of touch pad inputs
'' -- swaps LSB/MSB for correct binary input

  outa[PAD3..PAD0] := IS_HIGH                                   ' charge pads (all output high)   
  dira[PAD3..PAD0] := IS_OUTPUT
    
  dira[PAD3..PAD0] := IS_INPUT                                  ' float pads   
  pause(50)                                                     ' -- allow touch to discharge

  return (!ina[PAD3..PAD0] & $0F) >< 4                          ' return "1" for touched pads


pub pause(ms) | t

'' Delay program in milliseconds
'' -- ensure set_speed() used before calling

  t := cnt                                                      ' sync to system counter
  repeat (ms #>= 0)                                             ' delay > 0
    waitcnt(t += ms001)                                         ' hold 1ms


pub high(pin)

'' Makes pin output and high

  outa[pin] := IS_HIGH
  dira[pin] := IS_OUTPUT

var

  long  anicog                                                  ' cog running animation
  long  anistack[32]                                            ' stack space for Spin cog


pri run_animation(p_table, cycles) | p_leds

'' Run animation
'' -- p_table is pointer (address of) animation table
'' -- cycles is number of iterations to run
''    * 0 cycles runs "forever"
'' -- usually called with start_animation()

  if (cycles =< 0)
    cycles := POSX                                              ' run "forever"

  repeat cycles
    p_leds := p_table                                           ' point to table
    repeat byte[p_leds++]                                       ' repeat for steps in table
      set_leds(byte[p_leds++])                                  ' update leds
      pause(byte[p_leds++])                                     ' hold

      