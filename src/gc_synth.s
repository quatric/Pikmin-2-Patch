# hook: KPAD read, `lbz r0,0x10f(r31)` -- the read of the number of samples waiting
# in the channel's ring (r31 = the channel's KPAD struct, r27 = the channel).
#
# With a Wii Remote connected, its sampling callback fills the ring and there is
# always a sample waiting.  With none, nothing does -- so if the ring is empty and a
# GameCube pad answers on the matching port, make one sample from the pad right here
# (the same conversion the callback hook uses) and add it to the ring the way the
# callback would.  Scratch: r0, r3-r12; r3 holds the sample.
    lbz     0, 0x10f(31)
    cmpwi   0, 0
    bne     9f                          # samples are waiting: a remote is producing them
    cmplwi  27, 3
    bgt     9f
    lbz     0, 0x10e(31)
    cmplwi  0, 16
    blt     slot
    li      0, 0
slot:
    mulli   3, 0, 0x38
    add     3, 3, 31
    addi    3, 3, 0x110                 # the next ring slot
    li      0, 0
    stw     0, 0x00(3)
    stw     0, 0x04(3)
    stw     0, 0x08(3)
    stw     0, 0x0c(3)
    stw     0, 0x10(3)
    stw     0, 0x14(3)
    stw     0, 0x18(3)
    stw     0, 0x1c(3)
    stw     0, 0x20(3)
    stw     0, 0x24(3)
    stw     0, 0x28(3)
    stw     0, 0x2c(3)
    stw     0, 0x30(3)
    stw     0, 0x34(3)
    li      0, 0x68
    sth     0, 0x06(3)                  # accelerometer at rest, as a remote lying flat reads
    .set    CHAN, 27
    .set    SMP, 3
#include gc_convert.s
    lbz     0, 0x37(3)
    andi.   0, 0, 2
    beq     9f                          # no pad answered: nothing to add
    lbz     5, 0x10e(31)
    cmplwi  5, 16
    blt     idx
    li      5, 0
idx:
    addi    5, 5, 1
    stb     5, 0x10e(31)              # (r0 cannot be the base of an addi: it reads as zero)
    lbz     5, 0x10f(31)
    cmplwi  5, 16
    bge     full
    addi    5, 5, 1
    stb     5, 0x10f(31)
full:
    # tell the game a controller has connected, once, the way the sampling callback does
    lwz     0, 0x4d8(31)
    cmpwi   0, 0
    beq     9f
    lbz     0, 0x522(31)
    cmpwi   0, 0
    bne     9f
    li      0, 1
    stb     0, 0x522(31)
    mr      3, 27
    li      4, 0
    lwz     12, 0x4d8(31)
    mtctr   12
    bctrl
    li      0, 0
    stb     0, 0x523(31)
9:
    lbz     0, 0x10f(31)                # displaced instruction
