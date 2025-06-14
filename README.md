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