# radio-hq 📻

Walkie-talkie announcements for [Claude Code](https://claude.com/claude-code) on macOS.

When a session is waiting for you (a permission, a question, a plan to approve) or has finished, you get
a banner with the session name, a short sound effect and a radio voice:

> *kssh* — «Login bugfix, in attesa di istruzioni» — *beep-beep*

Made for people who run several sessions on several screens and keep missing the one that is stuck.

## Install

**Don't install it by hand.** Open Claude Code, paste this and send it:

```
Install https://github.com/Faripod/radio-hq
```

Claude follows [AGENTS.md](AGENTS.md): it checks your Mac, installs the plugin, runs the tests, plays you
a sample, helps you download a natural voice, and if something breaks it fixes it and proposes the fix
here. Your part is saying yes, listening and a couple of clicks macOS reserves for humans.

<details>
<summary>By hand</summary>

```bash
claude plugin marketplace add Faripod/radio-hq
claude plugin install radio-hq@radio-hq
```

Then `/reload-plugins` in an open session, or start a new one. Requires macOS with `jq` (built in since
macOS 15). Optional: `brew install terminal-notifier` for better banners, the Command Line Tools
(`xcode-select --install`) for the radio effect.
</details>

## What you hear

| When | Banner | Voice (Italian, the default) | Voice (English) |
|---|---|---|---|
| a permission prompt | *Aspetta un tuo ok* + the tool | «‹session›, in attesa di istruzioni» | «‹session›, awaiting instructions» |
| a question for you | *Ti sta facendo una domanda* + the question | «‹session›, domanda in attesa, passo» | «‹session›, question pending, over» |
| a plan to approve | *Piano da approvare* | «‹session›, piano pronto, attendo conferma» | «‹session›, plan ready, awaiting approval» |
| the end of a turn | *Ha finito* + the start of the answer | «‹session›, terminata, passo» | «‹session›, done, over» |

The session is named the way Claude Code shows it: your `/rename` first, then the automatic title. Runs
with `claude -p` (scripts, scheduled jobs) stay silent. Do Not Disturb / Focus mutes sound and voice.

## Everyday switches

Inside a session prefix them with `!`, e.g. `! radio-hq off`.

```
radio-hq                               status
radio-hq off | on                      the voice (banner and sound stay)
radio-hq tag personal                  this session is personal (work is the default)
radio-hq personal off                  mute personal sessions (work off works the same)
radio-hq test                          a sample announcement
```

`radio-hq --help` lists the rest. The command speaks the configured language, and accepts the Italian
words too (`lavoro`, `personale`, `nessuno`).

## Make it yours

Run `/radio-hq:setup`: Claude walks you through language, voice, sounds, radio effect and categories and
lets you hear each choice. Everything ends up in `~/.config/radio-hq/config`, a commented file you can
also edit or keep in your dotfiles (a symlink is fine).

**Voices.** radio-hq picks the best voice installed for the language. The natural ones (Luca, Federica,
Paola for Italian; Ava, Zoe, Evan for English) are a free download macOS keeps behind a few clicks in
VoiceOver Utility; `/radio-hq:setup` guides you.

**Sounds.** Fourteen effects from [Mixkit](https://mixkit.co) (alert, radar, gear shift, glitch, coin…).
They are not in this repository: the first run downloads them from Mixkit to your Mac, as their license
allows use but not redistribution. Any audio file of yours works as well.

## Privacy

Everything runs on your Mac. The only network call is the one-time sound download from Mixkit. Nothing
is logged unless you set `RADIO_HQ_LOG`, and even then without message text.

## Other systems

macOS only for now. The OS-specific part is one file and the tests define the behavior, so a Windows or
Linux port is mostly mechanical: see [PORTING.md](PORTING.md), or ask your agent to start one.

## Contributing

Bugs and fixes are welcome, ideally found and proposed by your agent as described in
[AGENTS.md](AGENTS.md). `tests/run.sh` must pass.

## License

MIT for the code. The sounds belong to Mixkit and are covered by the
[Mixkit License](https://mixkit.co/license/).
