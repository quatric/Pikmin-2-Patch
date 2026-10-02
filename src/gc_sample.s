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
    .set    CHAN, 29
    .set    SMP, 30
#include gc_convert.s
    addi    0, 28, 1                    # displaced instruction
