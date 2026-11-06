# Buck Rogers: Matrix Cubed

This project is a source reconstruction of SSI's DOS version of *Buck Rogers: Matrix Cubed*. Built with the compilers and tools SSI used, the source produces executables that are identical, byte for byte, to the ones SSI shipped.

## Read this first

- This source was reverse-engineered directly from the original game executables. It is **not** a clean-room reimplementation of the game, its engine or its mechanics.
- *Buck Rogers: Matrix Cubed*, *Buck Rogers*, Strategic Simulations, Inc. and all related names, trademarks, copyrights, artwork, writing, game data and other rights belong to their respective owners. I do not claim ownership of them. This project is not affiliated with or endorsed by those owners.
- This repository holds source code only. It includes no game executables and none of SSI's game data. You need to own a copy of *Buck Rogers: Matrix Cubed* to play. It is not sold digitally at the time of writing, so you need an original retail copy.
- AI coding tools were used throughout the project: Anthropic's Claude Code and OpenAI Codex.
- This is a hobby and preservation project. It is provided as-is, without warranty, customer service or a promise that it will work on your system. Back up your game and saved characters before replacing anything. Please do not ask the original rights holders for support with this project; see [Questions and bug reports](#questions-and-bug-reports).
- Because this source is derived from SSI's code, this repository does not make an open-source license grant. Making the source visible does not grant rights to the original game or its derived material. Anyone reusing or redistributing material from this repository is responsible for determining what they may legally use.

Laws concerning reverse engineering and derived works vary. You are responsible for complying with the laws and terms that apply to your copy of the game.

## What this project does

The `v1.0` tag reconstructs SSI's DOS release of version 1.0, byte for byte. The `main` branch holds version 1.0 and the scripts that build it.

Nothing here changes the game. The source reproduces SSI's program as it shipped, bugs included, and so do the files it builds: `START.EXE` and `GAME.OVR`. That includes SSI's original copy-protection check.

## Building From Source

The build runs entirely in [DOSBox-X](https://dosbox-x.com/): Borland's assembler and compiler and Microsoft's EXEPACK, run from `build/BUILD.BAT`, write every byte of the results. `build.sh` only prepares the folders, mounts the drives the batch file expects, reads the logs and checks the results.

You need:

- DOSBox-X 2026.08.31 or later, on your `PATH`.
- Bash 3.2 or later, `find`, `sed`, and `sha256sum` (Linux) or `shasum` (macOS).
- These DOS tools, copied into a `drive_c` folder in the repository root (it is ignored by Git):

| Folder | Files | Tool |
|---|---|---|
| `drive_c/TP6-1990` | `TPC.EXE`, `TURBO.TPL` | Turbo Pascal 6.0, the 1990 release |
| `drive_c/TASM` | `TASM.EXE` | Turbo Assembler 1.0 |
| `drive_c/TASM31` | `TASM.EXE` | Turbo Assembler 3.1, from Borland C++ 3.1 (for `ail.asm`) |
| `drive_c/EXEPACK` | `EXEPACK.EXE` | Microsoft EXEPACK 4.06 |

Then run:

```
./build.sh
```

`build.sh` reports everything that is missing before it stops. It warns when a tool is not the copy this reconstruction was made with, since a different release of a compiler can produce different bytes. The results go to `obj/` and the tools' logs to `build/logs/`. Finally, `build.sh` compares each result with the SHA-256 of SSI's file and says whether it is identical; it exits with an error if any file differs.

`build.sh` builds version 1.0.

To play the build, back up your game directory, then copy the files from `obj/` into it. Because they are SSI's original files, the game will ask its copy-protection question again; keep the manual or code wheel that came with your copy at hand.

## Questions and bug reports

This is a reconstruction of SSI's game, not a modified version of it. The original rights holders can't help with it. Please send questions and reports about the source or the build to talonius@brazencrows.com.

## Credits and Thanks

This work would not exist without SSI's original game and the people who have spent years documenting and exploring the Gold Box engine.

Special thanks to:

- [Gold Box Companion](https://gbc.zorbus.net/) for its character tools, automapping and years of practical Gold Box knowledge.
- [Gold Box Explorer](https://github.com/bsimser/Gold-Box-Explorer) for making the games' files and resources much easier to inspect and understand.
- Simeon Pilgrim's [CoAB project](https://github.com/simeonpilgrim/coab), an earlier reverse-engineering effort for *Curse of the Azure Bonds* that provided valuable reference work.

Thanks as well to everyone who has compared a rule against the manuals, documented a strange old bug, or kept an original copy of a Gold Box game around long enough for it to matter.
