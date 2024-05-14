# Weather plugin for tmux

Shows current temperature and weather conditions in the status line, data provided by [Open-Meteo](https://open-meteo.com/).

## Installation

---

### Requirements

- curl
- jq

### Using the TMUX Plugin Manager (TPM)

Add the plugin in `.tmux.conf`:

```bash
set -g @plugin 'dboursinos/tmux-weather'
```

Press `prefix + I` to fetch the plugin and source it. Done.

### Manual

Clone the repo somewhere. Add `run-shell` in the end of `.tmux.conf`:

```bash
run-shell PATH_TO_REPO/tmux-weather.tmux
```

NOTE: this line should be placed after `set-option -g status-right`.

## Usage

Add `#{weather}` somewhere in the right status line:

