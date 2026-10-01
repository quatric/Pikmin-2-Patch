# hook: KPAD read loop, right after the per-sample IR/geometry call returns
# (r19 = the raw sample, r31 = the channel's KPAD struct; the sample's marker
# byte says whether the sample was rewritten by the controller patch).
#
# KPAD has just found no IR (the sample says no DPD data) and cleared dpd_valid.
# A synthetic sample carries its pointer in 1/1000ths at sample+0x2a (X) and
# +0x2c (Y): write it into the status as the pointer position (x right, y down)
# and mark it valid.
#
# The literal pool after `bl 1f` holds the magic double used for int -> float
# and the two scale factors.
POINTER:
    lbz     0, 0x37(19)
    andi.   0, 0, MARKER
    beq     9f
    lha     4, 0x2a(19)
    lha     5, 0x2c(19)
    bl      1f
    .long   0x43300000, 0x80000000      # magic double 2^52 + 2^31
    .float  PTR_X                       # screen units per 1/1000th (right)
    .float  PTR_Y                       # screen units per 1/1000th (down; negative)
1:  mflr    6
    lis     7, 0x4330
    stw     7, 0x50(1)
    xoris   4, 4, 0x8000
    stw     4, 0x54(1)
    lfd     0, 0x50(1)
    lfd     4, 0(6)
    fsubs   0, 0, 4
    lfs     1, 8(6)
    fmuls   0, 0, 1
    stfs    0, 0x20(31)                 # pos.x
    xoris   5, 5, 0x8000
    stw     5, 0x54(1)
    lfd     0, 0x50(1)
    fsubs   0, 0, 4
    lfs     1, 12(6)
    fmuls   0, 0, 1
    stfs    0, 0x24(31)                 # pos.y
    li      0, 2
    stb     0, 0x5e(31)                 # dpd_valid
9:
