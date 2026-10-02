"""Build the GameCube controller feature for one region from src/gc_sample.s and src/pointer.s."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_common as g
from layout import GC_BASE, GC_END
from ops import Feature

USA_DOL = None

# the displaced `b`, as an absolute jump so the routine works wherever a code handler puts it
JUMP = '    lis     12, LOOP_END@ha\n    addi    12, 12, LOOP_END@l\n    mtctr   12\n    bctr\n'


def build(region, dol):
    g.USA_DOL = USA_DOL
    at, w = g.sites(region, dol)
    consts = dict(g.WM, **g.PAD)
    ops, cur = [], GC_BASE
    h, size = g.hook(at['addi'], w['addi'], cur, g.read('gc_sample.s'), {}, consts,
                     'KPAD sampling callback: GameCube pad -> Wii Remote + Nunchuk sample')
    ops.append(h)
    cur += size
    target = g.decode_branch(w['b'], at['b'])
    h, size = g.hook(at['b'], w['b'], cur, g.pointer_source(2, '', JUMP), {'LOOP_END': target}, consts,
                     'KPAD read loop: pointer from the sticks')
    ops.append(h)
    cur += size
    ex, ew = g.gc_extra_sites(region, dol)
    h, size = g.hook(ex['ring'], ew['ring'], cur, g.read('gc_synth.s'), {}, consts,
                     'KPAD read: no Wii Remote, so make the sample from the GameCube pad')
    ops.append(h)
    cur += size
    h, size = g.hook(ex['probe'], ew['probe'], cur, g.read('gc_probe.s'), {'PROBE_BODY': ex['probe'] + 4}, consts,
                     'WPADProbe: a GameCube pad counts as a connected controller')
    ops.append(h)
    cur += size
    if cur > GC_END:
        raise SystemExit('gc code overflows its window: 0x%X > 0x%X' % (cur, GC_END))
    return Feature('gc', 'GameCube controller', region, ops)
