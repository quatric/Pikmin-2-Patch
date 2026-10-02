# The GameCube pad -> Wii Remote + Nunchuk conversion shared by the sampling-callback
# hook and the remote-less sample generator.  Assembled with
#   CHAN = the register holding the channel number, SMP = the register holding the sample
# and ends at the local label 9 (the caller places it).  Scratch: r0, r4-r12.
    cmplwi  CHAN, 3
    bgt     9f
    mulli   5, CHAN, 12
    lis     6, 0xCD00
    add     6, 6, 5
    lwz     8, 0x6404(6)                # INBUFH
    cmpwi   8, 0
    blt     9f                          # error / no pad
    andis.  9, 8, 0x0080
    beq     9f                          # not a pad response
    lbz     4, 0x29(SMP)
    cmplwi  4, 0
    bne     9f                          # only a good sample
    lwz     12, 0x6408(6)               # INBUFL
    srwi    5, 8, 16                    # PAD buttons (r5 for mapbit)
    rlwinm  10, 8, 24, 24, 31
    addi    10, 10, -128                # stick X
    rlwinm  11, 8, 0, 24, 31
    addi    11, 11, -128                # stick Y
    rlwinm  8, 12, 8, 24, 31
    addi    8, 8, -128                  # C stick X
    rlwinm  9, 12, 16, 24, 31
    addi    9, 9, -128                  # C stick Y
    lhz     6, 0x00(SMP)                 # Wii Remote buttons
    li      7, 0
    mapbit  PAD_A,     WM_A
    mapbit  PAD_B,     WM_B
    mapbit  PAD_X,     WM_C
    mapbit  PAD_Y,     WM_MINUS
    mapbit  PAD_START, WM_PLUS
    mapbit  PAD_L,     WM_Z
    mapbit  PAD_R,     WM_RIGHT
    mapbit  PAD_Z,     WM_UP
    # D-pad: carrying a Pikmin (A held) or not
    andi.   0, 5, PAD_A
    bne     carry
    andi.   0, 6, WM_A
    bne     carry
    mapbit  PAD_UP,    WM_1
    mapbit  PAD_DOWN,  WM_2
    b       dpad_done
carry:
    mapbit  (PAD_LEFT | PAD_RIGHT), WM_B
    mapbit  (PAD_UP | PAD_DOWN),    WM_DOWN
dpad_done:
    # C stick active -> swarm, and the pointer follows it
    absr    4, 8
    cmplwi  4, 30
    bge     cstick
    absr    4, 9
    cmplwi  4, 30
    bge     cstick
    mr      8, 10                       # pointer = control stick
    mr      9, 11
    b       ptr_done
cstick:
    ori     7, 7, WM_DOWN
ptr_done:
    or      6, 6, 7
    sth     6, 0x00(SMP)
    # control stick (+-100) -> Nunchuk stick (+-71 is full deflection)
    mulli   10, 10, 205
    srawi   10, 10, 8
    clamp   10, 127
    mulli   11, 11, 205
    srawi   11, 11, 8
    clamp   11, 127
    # pointer in 1/1000ths
    dead    8, 8
    mulli   8, 8, 10
    clamp   8, 1000
    dead    9, 8
    mulli   9, 9, 10
    clamp   9, 1000
    li      0, 1
    stb     0, 0x28(SMP)                 # device: Nunchuk
    li      0, 4
    stb     0, 0x36(SMP)                 # data format: Nunchuk buttons + accelerometer
    stb     10, 0x30(SMP)
    stb     11, 0x31(SMP)
    sth     8, 0x2a(SMP)
    sth     9, 0x2c(SMP)
    lbz     0, 0x37(SMP)
    ori     0, 0, 2
    stb     0, 0x37(SMP)                 # marker bit 1: GameCube pointer
9:
