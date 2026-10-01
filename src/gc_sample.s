# hook: KPAD sampling callback, the `addi r0,r28,1` after the data format is stored
# (r28 = ring index, r29 = channel, r30 = the sample).
#
# If a GameCube pad answers on the SI port with the same number as the channel,
# its state is merged into the Wii Remote + Nunchuk sample the game was written
# for.  The SI hardware keeps the pad's answer in SIC<n>INBUFH/L (0xCD006404 +
# 12*n, +4): INBUFH [31] error, [23] a real pad's answer, [29:16] buttons,
# [15:8] stick X, [7:0] stick Y; INBUFL cstick X, cstick Y, L, R.
#
# The layout follows the original GameCube game's controls, expressed as the
# New Play Control inputs that do the same thing:
#
#   Control stick   move; the pointer follows it (the cursor sits where the stick points)
#   C stick         swarm: D-pad down held, the pointer follows the C stick
#   A  B            A  B
#   X               C   (dismiss / lie down)
#   Y               -   (switch leaders)
#   L               Z   (camera forward / rotate)
#   R               D-pad right (camera distance / ground-level angle)
#   Z               D-pad up    (camera vertical angle)
#   Start           +
#   D-pad           while A is held (carrying a Pikmin): left/right = B (swap type),
#                   up/down = D-pad down (swap maturity);
#                   otherwise up = 1 (bitter spray), down = 2 (spicy spray)
    cmplwi  29, 3
    bgt     9f
    mulli   5, 29, 12
    lis     6, 0xCD00
    add     6, 6, 5
    lwz     8, 0x6404(6)                # INBUFH
    cmpwi   8, 0
    blt     9f                          # error / no pad
    andis.  9, 8, 0x0080
    beq     9f                          # not a pad response
    lbz     4, 0x29(30)
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
    lhz     6, 0x00(30)                 # Wii Remote buttons
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
    sth     6, 0x00(30)
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
    stb     0, 0x28(30)                 # device: Nunchuk
    li      0, 4
    stb     0, 0x36(30)                 # data format: Nunchuk buttons + accelerometer
    stb     10, 0x30(30)
    stb     11, 0x31(30)
    sth     8, 0x2a(30)
    sth     9, 0x2c(30)
    lbz     0, 0x37(30)
    ori     0, 0, 2
    stb     0, 0x37(30)                 # marker bit 1: GameCube pointer
9:
    addi    0, 28, 1                    # displaced instruction
