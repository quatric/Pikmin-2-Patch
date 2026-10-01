# Technical notes

How the two patches work, where they hook, and how one set of data becomes a
patched `main.dol`, a Gecko code list and a Riivolution patch. For installing
and playing, see the [README](../README.md).

Addresses below are the **USA** `main.dol` (`R92E01`) unless noted; the table at
the end lists the other releases.

## One data set, three outputs

Every patch is a list of operations on one release's `main.dol`:

| Operation | Static (`main.dol`) | Gecko | Riivolution |
| --- | --- | --- | --- |
| **Hook** — replace one instruction with a branch to a routine that runs the displaced instruction and branches back | branch + trampoline in the injected section | `C2` code | `<memory>` (branch + trampoline) |

`tools/prebuilt/<feature>_<disc id>.json` holds those operations, including the
retail instruction expected at every site. `tools/ops.py` turns them into each
format, `tools/patcher.py` applies them (and refuses a `main.dol` whose sites do
not match, so already-modified or foreign dumps are never touched), and
`tools/build.py` writes `codes/` and `riivolution/`. `tools/check.py` fails if
the committed files drift from the data; `tools/verify.py` checks the data
against real retail DOLs for every combination of patches.

**Hooks are self-contained.** A routine carries everything it needs and reaches
game code through absolute addresses (`lis`/`addi`/`mtctr`/`bctrl`), never a
relative `bl` — a Gecko code handler runs the routine from wherever it keeps it,
so a relative branch to the game would land in the wrong place. `tools/check.py`
rejects any relative branch that leaves its routine. Routines hold no variables
of their own; the static build parks them in one new text section at
`0x80001820` (the Wii's boot-time scratch area, which this game never touches:
the game's own code starts at `0x80004000` and nothing in the retail DOLs
addresses `0x80001800-0x80003000`).

## The idea: make every controller a Wii Remote + Nunchuk

New Play Control! Pikmin 2 is the GameCube game with its controls rewritten for
a Wii Remote and a Nunchuk. The game links the SDK's `KPAD` library, whose
`KPADRead` (`0x8018D744`) turns the Wii Remote's raw samples into a status
structure (0x84 bytes per sample: buttons, pointer, extension data). The
game's `Controller` class reads that status, and everything it does with a
Nunchuk hangs off `status.dev_type == 1` (the stick floats at status `+0x60/+0x64`,
the C and Z bits in the button word).

Instead of teaching the game about a Classic Controller or a GameCube pad, both
patches rewrite the **raw sample** into a Nunchuk sample before `KPADRead` ever
sees it. Everything downstream — menus, camera, cursor, the Onion — is the
game's ordinary, tested Nunchuk code.

KPAD keeps a 16-slot ring of `WPADStatus` samples per channel (`0x538`-byte
channel structs from `0x8062EF40`, ring at `+0x110`, `0x38` bytes per slot,
index at `+0x10E`). Its sampling callback (`0x8018E1EC`) reads one sample into
a slot with `WPADRead`, stores the data format in slot byte `0x36`, then lets
`KPADRead` consume the ring later. The fields that matter:

| Slot offset | Field |
| --- | --- |
| `0x00` | Wii Remote buttons (`0x0001` Left … `0x0800` A, `0x1000` −, `0x2000` Nunchuk Z, `0x4000` Nunchuk C, `0x8000` HOME) |
| `0x28` | device type: 0 remote, 1 Nunchuk, 2 Classic Controller |
| `0x29` | error (0 = good sample) |
| `0x2A…` | Classic Controller: buttons `+0x2A`, left stick `+0x2C/+0x2E`, right stick `+0x30/+0x32` (signed 16-bit); Nunchuk: stick `+0x30/+0x31` (signed 8-bit) |
| `0x36` | data format (3-5 Nunchuk, 6-8 Classic Controller) |
| `0x37` | unused padding byte — the patches use it as a marker |

KPAD's Nunchuk code is only reached when the sample says device 1 *and* format
3-5, and it turns the signed-byte stick into a float with a dead zone of 15 and a
full-deflection value of 71. The Classic Controller path uses 60 and 308 on
16-bit sticks.

## The sample hook

| | Site | Displaced instruction |
| --- | --- | --- |
| Classic Controller | `0x8018E26C` | `stb r3,0x36(r30)` |
| GameCube controller | `0x8018E270` | `addi r0,r28,1` |

At those points `r30` is the slot and `r29` the channel. The hook first resets
the marker, then converts:

- **Classic Controller** (`cc_sample.s`): only for device 2 with a good sample.
  Buttons are mapped to Wii Remote / Nunchuk bits and ORed into the remote's own;
  the left stick is scaled by 59/256 (308 → 71) into the Nunchuk stick bytes; the
  right stick is dead-zoned, scaled by 13/4 (308 → 1001) and stored as a pointer in
  1/1000ths at slot `+0x2A/+0x2C`; device becomes 1, format 4, marker bit 0 set.
- **GameCube controller** (`gc_sample.s`): the SI hardware keeps each port's
  latest answer in `SIC<n>INBUFH/L` (`0xCD006404 + 12*n`, `+4`): bit 31 error,
  bit 23 a real pad's answer, bits 29-16 the buttons, then the two sticks, the
  C stick and the triggers. Port *n* feeds channel *n*. The pad's state is merged
  the same way, with the original GameCube game's layout (see below), and marker bit 1
  is set. No console state is stored anywhere; a missing pad is recognised by its
  own error/valid bits.

### GameCube layout

The GameCube game's controls differ from the Nunchuk version's, so each GameCube
input becomes the Wii input that does the same thing in this game:

| GameCube | Wii input | Why |
| --- | --- | --- |
| Control stick | Nunchuk stick + pointer | the cursor sits where the stick points |
| C stick | D-pad down (swarm) + pointer | on the Wii, Pikmin go to the cursor |
| A, B | A, B | |
| X | C | dismiss / lie down |
| Y | − | switch leaders |
| L | Z | camera forward / rotate |
| R | D-pad right | camera distance / ground-level angle |
| Z | D-pad up | camera vertical angle |
| Start | + | |
| D-pad up/down | 1 / 2 | ultra-bitter / ultra-spicy spray |
| D-pad, A held | left/right → B, up/down → D-pad down | swap type / maturity of the Pikmin in hand |

Holding A means a Pikmin is in hand (pressing holds, releasing throws), so A is
the stateless proxy that separates the GameCube D-pad's two jobs.

## The pointer hook

A Nunchuk sample has no IR data, so KPAD reports no pointer and the game would
have nothing to aim its cursor with. After each sample's per-sample IR/geometry
call (`bl 0x8018CD28`, `0x8018DE10`), KPAD's status for that sample is complete
and `dpd_valid` has just been cleared. The pointer hook looks at the marker byte
of the raw sample (`r19` is the sample; `r31` the channel struct); if the
patch rewrote it, it converts the stored 1/1000ths to floats and writes them as
`pos.x` (`+0x20`) and `pos.y` (`+0x24`, up is negative) and sets `dpd_valid`
(`+0x5E`) to 2 — exactly what the game sees from a real, tracked remote.

Because both sample hooks write the same fields, each patch has its own pointer
hook at its own site: Classic Controller at the `bl` (`0x8018DE10`), GameCube at the
`b` that follows it (`0x8018DE14`), and each only acts on its own marker bit.
Both reach their displaced branch through an absolute jump.

## Other releases

The KPAD library is the same code in every release (`RVL_SDK - KPAD` build Aug 8
2007), but moved. The four sites were carried over by masked-signature search
(`tools/sig.py`, which ignores branch targets and address-sized immediates and
demands exactly one match):

| | USA | Europe | Japan (Rev 1) |
| --- | --- | --- | --- |
| `stb r3,0x36(r30)` | `0x8018E26C` | `0x8018E6CC` | `0x8018E48C` |
| `addi r0,r28,1` | `0x8018E270` | `0x8018E6D0` | `0x8018E490` |
| `bl` IR/geometry call | `0x8018DE10` | `0x8018E270` | `0x8018E030` |
| `b` after it | `0x8018DE14` | `0x8018E274` | `0x8018E034` |

## How it was tested

Dolphin, with its GDB stub reading the channel's KPAD struct and ring while a pipe
device presses buttons and moves sticks (Classic Controller on the emulated Wii
Remote, GameCube pad on port 1): every button lands on the bit above, the
sticks arrive as Nunchuk stick floats, and the pointer follows the right stick
/ C stick / control stick. The same checks pass on a disc image rebuilt by the
patcher (no Gecko codes). `tools/verify.py` re-checks every site against retail
DOLs. Nothing here has been run on a console.
