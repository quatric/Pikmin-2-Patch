"""The three retail releases of Pikmin 2 (New Play Control!) and their disc versions.

The Japanese release is revision 1 of the disc.
"""
REGIONS = {
    'R92E01': dict(label='New Play Control! Pikmin 2 (USA)', short='USA', version=0),
    'R92P01': dict(label='New Play Control! Pikmin 2 (Europe/Australia)', short='Europe', version=0),
    'R92J01': dict(label='New Play Control! Pikmin 2 (Japan, Rev 1)', short='Japan', version=1),
}

# retail DOL sizes, to give a clear error on someone else's modified dump
DOL_SIZES = {'R92E01': 6126432, 'R92J01': 6127264, 'R92P01': 6131648}
