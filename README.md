# Clipixir

_A friendly and powerful command-line clipboard manager and picker for macOS (and Linux, with minor tweaks)._

**Features:**
- Remembers your clipboard history securely in a local file.
- Duplicate prevention and automatic "recency promotion."
- Usage count and timestamp tracking.
- Interactive search+fuzzy filter from the terminal.
- Keeps only the most relevant 1000 entries—longer-term entries can be trimmed smartly.
- Beautiful colored display, works in any terminal.

---

## **Install & Build**

```sh
git clone https://github.com/Pranavj17/clipixir.git
cd clipixir
mix deps.get
mix escript.build
```

## **Usage**

```Starting Clipixir
Tracking clipboard...
# (Remains quiet and logs nothing else. Ctrl+C to stop.)
```

```Picker
$ ./clipixir select
─ Clipboard History Picker ─ (showing 3 of 3)
[0] Terminal           [Count: 3 Last: 2024-05-14 17:10]
──────────────────────────────────────────────
[1] StackOverflow      [Count: 2 Last: 2024-05-14 09:30]
──────────────────────────────────────────────
[2] Hello World!       [Count: 1 Last: 2024-05-13 19:02]
──────────────────────────────────────────────
Type number, /search, or q to quit: /Stack
─ Clipboard History Picker ─ (showing 1 of 1)
[0] StackOverflow      [Count: 2 Last: 2024-05-14 09:30]
──────────────────────────────────────────────
Type number, /search, or q to quit: 0
Copied entry #0 to clipboard, now promoted to top!
```