#!/usr/bin/env bash

# Load helper functions
source ../scripts/helpers.sh
source ../scripts/weather.sh

# Test get_location function
# Test case 1
# Test when the location is set in the tmux options
# Expected: The function should return the coordinates of the location
test_get_location_location_set_file_exists() {
  set_tmux_option "@weather-location" "Boston"
  set_tmux_option "@weather-coordinates-cache-file" "${PWD}/files/.city-coordinates.json"
  # Call the function
  result=$(get_location)
  echo "$result"
  # Assert number of values
  assertEquals 2 $(echo "$result" | wc -w)
  unset_tmux_option "@weather-location"
  unset_tmux_option "@weather-coordinates-cache-file"
  tmux source-file "${HOME}/.tmux.conf"
}

# Test case 2
# Test when the location is set in the tmux options and the cache doesn't exist
# Expected: The function should return the coordinates of the location
test_get_location_location_set_no_file() {
  set_tmux_option "@weather-location" "Boston"
  set_tmux_option "@weather-coordinates-cache-file" "${PWD}/files/.city-coordinates-new.json"
  # Call the function
  result=$(get_location)
  echo $result
  # Assert number of values
  assertEquals 2 $(echo "$result" | wc -w)
  # Assert file is created
  assertTrue "[ -f ${PWD}/files/.city-coordinates-new.json ]"
  unset_tmux_option "@weather-location"
  unset_tmux_option "@weather-coordinates-cache-file"
  tmux source-file "${HOME}/.tmux.conf"
  rm "${PWD}/files/.city-coordinates-new.json"
}

# Test case 3
# Test when the location is not set in the tmux options.
# However a cache file exists with the location coordinates.
# Expected: The function should return the coordinates of the current location.
test_get_location_location_not_set() {
  unset_tmux_option "@weather-location"
  set_tmux_option "@weather-location-cache-path" "${PWD}/files/.weather-location.json"
  # Mock the get_file_age function
  get_file_age() {
    echo 100
  }
  # Call the function
  result=$(get_location)
  echo "$result"
  # Assert number of values
  assertEquals 2 $(echo "$result" | wc -w)
  unset_tmux_option "@weather-location"
  unset_tmux_option "@weather-coordinates-cache-file"
  tmux source-file "${HOME}/.tmux.conf"
}

# Test case 4
# Test when the location is not set in the tmux options and the cache file exists
# A cache file doesn't exist with the location coordinates.
# Expected: The function should return the coordinates of the current location
# and update the cache file with the new coordinates
test_get_location_location_not_set_cache_file_not_exists() {
  unset_tmux_option "@weather-location"
  set_tmux_option "@weather-location-cache-path" "${PWD}/files/.weather-location_new.json"
  # Mock the get_file_age function
  get_file_age() {
    echo 400
  }
  # Call the function
  result=$(get_location)
  # Assert number of values
  assertEquals 2 $(echo "$result" | wc -w)
  # Assert file is created
  assertTrue "[ -f ${PWD}/files/.weather-location_new.json ]"
  unset_tmux_option "@weather-location-cache-path"
  tmux source-file "${HOME}/.tmux.conf"
  rm "${PWD}/files/.weather-location_new.json"
}

# Test get_weather function
# Test case 1
# Test when the latitude and longitude are not set
# Expected: The function should return an error message
test_get_weather_latitude_longitude_not_set() {
  # Call the function
  result=$(get_weather)
  # Assert the result
  assertEquals "Latitude and longitude are required." "$result"
}

# Test case 2
# Test when the latitude and longitude are set
# Expected: The function should return the weather information
# for the given coordinates
test_get_weather_latitude_longitude_set() {
  set_tmux_option "@weather-show-fahrenheit" "true"
  # Call the function
  result=$(get_weather 42.3601 -71.0589) # Boston coordinates
  echo "$result"
  # Assert the result contains the string "temperature" and "cloud_cover" and "rain" and "percipitation"
  assertTrue "echo $result | grep -q 'temperature'"
  assertTrue "echo $result | grep -q 'cloud_cover'"
  assertTrue "echo $result | grep -q 'rain'"
  assertTrue "echo $result | grep -q 'precipitation'"
  assertTrue "echo $result | grep -q 'is_day'"
  unset_tmux_option "@weather-show-fahrenheit"
  tmux source-file "${HOME}/.tmux.conf"
}

. shunit2
