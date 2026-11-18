**English** | [Français](README.fr.md)

# bose-keepalive

A small macOS tool that keeps a speaker from going to standby (auto-off, auto-standby) by continuously sending it a signal you can't hear.

## The problem

Many speakers and audio systems (mine is a Bose system) switch off or go to standby when they stop receiving a signal for a while. That saves power, but it is annoying day to day: after a stretch of silence, you have to go and turn the speaker back on by hand, and you miss the start of the next song or video.

## The principle

The idea is simple: if the speaker thinks it is receiving a signal, it doesn't fall asleep. So the Mac sends it **a subsonic sine wave**: a pure, very low tone, at 20 Hz by default.

- **Why you can't hear it.** 20 Hz is the bottom of what the human ear can perceive, and at a low level you would need an enormous volume to feel it. The speakers themselves, even with a subwoofer, reproduce it very little. In practice, there is nothing to hear.
- **Why the speaker still sees it.** A speaker's signal detector generally measures a voltage at the input, regardless of frequency. A 20 Hz signal reaches it like any other.
- **Why it is safe.** The level is low (a few tens of decibels below the digital maximum), and at 20 Hz the speaker drivers barely move.
- **Why not an ultrasound.** You could also use a tone too high to be heard (above 20 kHz), but that is a bad idea: it can heat the tweeters (the small high-frequency speakers), bother pets, and many sound cards don't even reproduce it. A very low tone is safer.

The `bose-tone` program computes the sine wave in real time and never stops, with a one-second fade-in at start and a half-second fade-out at stop: no pop when you stop or restart it. If the Mac's audio configuration changes (a sound card unplugged, for example), it restarts the sound by itself.

## Requirements

- **macOS.** The tool uses the system's audio components and the `launchd` background task manager.
- **`swiftc`**, the Swift compiler, provided by the Xcode command line tools. To check whether you have it: `swiftc --version`. If not, `xcode-select --install` installs them (full Xcode isn't needed).
- **SwiftBar** (optional), to control the tool from the menu bar: [swiftbar.app](https://swiftbar.app).

## Installation

```bash
git clone https://github.com/ThomasHMD/bose-keepalive.git
cd bose-keepalive
./bose-keepalive.sh install
```

The installation compiles the generator, registers a `launchd` agent and starts it. The signal is then restarted at every login, and restarted by itself if it stops. The runtime files (binary, settings, error log) are kept in `~/Library/Application Support/bose-keepalive/`.

The cloned folder must stay in place: the SwiftBar menu and the control script refer to it. To update the tool, run `git pull` then `./bose-keepalive.sh install` again.

By default, the signal is played on **your Mac's default sound output**, that is the one chosen in System Settings > Sound. If your speaker is plugged into a sound card (a Scarlett 2i2, for example) that isn't the default output, give its name (see below).

## Commands

```bash
./bose-keepalive.sh status          # marche | coupe | panne | absent, then frequency and level
./bose-keepalive.sh off             # stop (the stop holds after a reboot)
./bose-keepalive.sh on              # restart (reinstalls if needed)
./bose-keepalive.sh niveau -24      # change the level, in dBFS
./bose-keepalive.sh test 10         # play the signal for 10 seconds (stop the agent first: off)
./bose-keepalive.sh uninstall       # stop everything and remove
```

The `status` answers are French words: `marche` (running), `coupe` (stopped), `panne` (failed), `absent` (not installed).

### Settings

Three settings, given as environment variables at install time and remembered afterwards:

| Variable | Default | Role |
|---|---|---|
| `FREQ` | `20` | Signal frequency, in hertz |
| `LEVEL_DB` | `-30` | Level, in dBFS (0 is the maximum, negative values are quieter) |
| `SORTIE` | empty | Name of the sound card to play on ("sortie" is French for output); empty = system default output |

Examples:

```bash
FREQ=30 ./bose-keepalive.sh install
LEVEL_DB=-24 ./bose-keepalive.sh install
SORTIE="Scarlett 2i2 USB" ./bose-keepalive.sh install
```

The card name is the one shown by System Settings > Sound > Output (or by the command `system_profiler SPAudioDataType`). When a name is given, the signal is played directly on that card, and nowhere else: if it is absent, nothing is played on another output, and the tool retries every 30 seconds. Playing directly on the card also avoids the pops that audio routing software (Background Music, Loopback and the like) can cause when set as the default output, as it now and then catches up the clock drift with the real card.

To go back to the default output after naming a card: `./bose-keepalive.sh uninstall`, then `./bose-keepalive.sh install`.

## The SwiftBar menu

If you use SwiftBar, link the plugin into its plugins folder (the one you chose the first time you ran SwiftBar):

```bash
ln -s "$PWD/bose-keepalive.5m.sh" "<SwiftBar plugins folder>/"
```

An icon appears in the menu bar: a full speaker when the signal is being sent, a crossed-out speaker when it is stopped, a triangle when the agent is installed but stopped. The menu lets you:

- stop or restart the signal;
- choose the level: -36, -30, -24 or -18 dBFS (if the signal is stopped, the level is saved without restarting anything);
- open this documentation.

The menu only shows if SwiftBar is running: remember to add it to your Mac's login items.

## Limits

- It isn't guaranteed to work with every speaker: some ignore very weak or very low signals. See the next section.
- With an external sound card, its volume knob (if it has one) also attenuates this signal. Near zero, the signal can fall below the speaker's threshold. Likewise, the Mac's volume affects the level sent.
- When `SORTIE` is empty, the signal follows the system default output. If that changes (headphones plugged in, AirPlay), the signal goes somewhere other than your speaker. In that case, give the card's name.
- The signal only exists while the Mac is on and awake: a sleeping Mac sends nothing.
- Works on macOS only.

## If it doesn't work

If the speaker still goes to standby, in this order:

1. Check that the agent is running: `./bose-keepalive.sh status` must answer `marche`. If not, `./bose-keepalive.sh on`. The log `~/Library/Application Support/bose-keepalive/erreurs.log` has one line per sound restart: if it has many, something is wrong on the audio side.
2. **Raise the level**, in steps: `./bose-keepalive.sh niveau -24`, then `-18`. At 20 Hz, it should still be inaudible.
3. **Raise the frequency**, if the speaker filters very low frequencies: `FREQ=30 ./bose-keepalive.sh install`, then 40. Beyond about 40 Hz, a subwoofer can start to make it audible: listen closely after each change.
4. Check that the signal really comes out on the right output: run a test (`off`, then `test 10`) and, if needed, give the card's name with `SORTIE`.

## License

MIT, see [LICENSE](LICENSE).

This project is not affiliated with Bose Corporation or any speaker manufacturer; "Bose" here only refers to the hardware I wrote it for.
