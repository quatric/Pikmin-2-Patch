# hook: KPAD sampling callback, the `stb r3,0x36(r30)` that stores the sample's
# data format (r29 = channel, r30 = the sample in KPAD's ring buffer, a WPADStatus).
#
# A Classic Controller plugged into the Wii Remote is rewritten, in place, into
# the Wii Remote + Nunchuk sample the game was written for, so the rest of KPAD
# and the game run their ordinary Nunchuk code:
#
#   left stick      -> Nunchuk stick
#   right stick     -> pointer (carried to `pointer.s` in sample bytes 0x2a/0x2c)
#   buttons         -> Wii Remote / Nunchuk bits (table below)
#
# sample + 0x37 is the marker byte (bit 0 = "Classic Controller pointer"); it is
# the last byte of the 0x38-byte ring slot and nothing else uses it.
#
#   Classic Controller            Wii Remote / Nunchuk
#   A  B                          A  B
#   X                             C   (dismiss / lie down)
#   Y  -                          -   (switch leaders)
#   ZL                            Z   (camera)
#   L  R                          1  2   (the two sprays)
#   ZR                            D-pad down (swarm)
#   D-pad                         D-pad
#   +  HOME                       +  HOME
    stb     3, 0x36(30)                 # displaced instruction
    li      0, 0
    stb     0, 0x37(30)                 # marker: nothing synthetic yet
    lbz     4, 0x29(30)
    cmplwi  4, 0
    bne     9f                          # only a good sample
    lbz     4, 0x28(30)
    cmplwi  4, 2
    bne     9f                          # only a Classic Controller
    lhz     5, 0x2a(30)                 # Classic Controller buttons
    lhz     6, 0x00(30)                 # Wii Remote buttons
    lha     8, 0x2c(30)                 # left stick X
    lha     9, 0x2e(30)                 # left stick Y
    lha     10, 0x30(30)                # right stick X
    lha     11, 0x32(30)                # right stick Y
    li      7, 0
    mapbit  CC_A,      WM_A
    mapbit  CC_B,      WM_B
    mapbit  CC_X,      WM_C
    mapbit  CC_Y,      WM_MINUS
    mapbit  CC_MINUS,  WM_MINUS
    mapbit  CC_PLUS,   WM_PLUS
    mapbit  CC_HOME,   WM_HOME
    mapbit  CC_ZL,     WM_Z
    mapbit  CC_L,      WM_1
    mapbit  CC_R,      WM_2
    mapbit  CC_ZR,     WM_DOWN
    mapbit  CC_UP,     WM_UP
    mapbit  CC_DOWN,   WM_DOWN
    mapbit  CC_LEFT,   WM_LEFT
    mapbit  CC_RIGHT,  WM_RIGHT
    or      6, 6, 7
    sth     6, 0x00(30)
    # left stick (+-308) -> Nunchuk stick (+-71 is full deflection)
    mulli   8, 8, 59
    srawi   8, 8, 8
    clamp   8, 127
    mulli   9, 9, 59
    srawi   9, 9, 8
    clamp   9, 127
    # right stick (+-308) -> pointer in 1/1000ths
    dead    10, 40
    mulli   10, 10, 13
    srawi   10, 10, 2
    clamp   10, 1000
    dead    11, 40
    mulli   11, 11, 13
    srawi   11, 11, 2
    clamp   11, 1000
    li      0, 1
    stb     0, 0x28(30)                 # device: Nunchuk
    li      0, 4
    stb     0, 0x36(30)                 # data format: Nunchuk buttons + accelerometer
    stb     8, 0x30(30)
    stb     9, 0x31(30)
    sth     10, 0x2a(30)
    sth     11, 0x2c(30)
    li      0, 1
    stb     0, 0x37(30)
9:
