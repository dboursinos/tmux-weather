# Weather plugin for tmux

Shows current temperature and weather conditions in the status line, data provided by [Open-Meteo](https://open-meteo.com/).

## Installation

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

`set-option -g status-right "#{weather}"`

## Customization

This plugin can be customized using by setting the following parameters inside `.tmux.conf`:

- `set-option -g @weather-interval 15` - Set up the weather update interval in minutes. By default, it is 15 minutes and cannot be lower than 5 minutes.
- `set-option -g @weather-cache-path "/tmp/.weather-${latitude}\_${longitude}.json"` - Set up the location of the cache file that stores the current weather.
- `set-option -g @weather-show-fahrenheit "true"` - The temperatures can appear either measure in Celsius or Fahrenheit.
- `set-option -g @weather-location ""` - Set up the location you wish to display the weather for. If empty the location will be determined based on your IP address.
- `set-option -g @weather-coordinates-cache-file "/tmp/.city-coordinates.json"` - Set up the location of the file that stores the coordinates of cities that have been chosen to display weather.
- `set-option -g @weather-location-interval 240` - Set up the interval you wish to determine your location based on your IP in minutes. By default, it is 240 minutes and cannot be lower than 120 minutes. It is only used if `@weather-location` is empty.
- `set-option -g @weather-location-cache-path "/tmp/.weather-location.json"` - Set up the location of the file that stores the last estimated coordinates based on the IP address. It is only used if `@weather-location` is empty.

## License

The tmux-weather plugin is released under the [MIT License](https://opensource.org/licenses/MIT).
