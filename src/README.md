# Sources

The PowerPC routines the patches inject, as `devkitPPC` assembly, and the
generators that place them.

| File | Hook |
| --- | --- |
| `macros.s` | assembler macros shared by the routines |
| `cc_sample.s` | Classic Controller sample -> Wii Remote + Nunchuk sample (KPAD sampling callback) |
| `gc_sample.s` | GameCube pad -> Wii Remote + Nunchuk sample (KPAD sampling callback) |
| `pointer.s` | pointer from a stick, written into KPAD's output (KPAD read loop); used by both patches |
| `gen_common.py` | site addresses, button tables and the code shared by the two builders |
| `gen_cc.py` `gen_gc.py` | build one feature for one release from a retail `main.dol` |

`python3 tools/gen_prebuilt.py` assembles everything and writes
`tools/prebuilt/*.json`, which is what the patcher ships and reads. It needs
devkitPPC and your own `main.dol` dumps (see the top-level README); end users do
neither.

Symbols such as `WM_A`, `CC_X`, `PAD_START` and `IR_CALL` are filled in at build
time (`asm.py` passes them to the assembler and linker), and the generators check
the retail bytes at every site before emitting anything.
