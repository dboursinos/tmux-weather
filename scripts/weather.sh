#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$CURRENT_DIR/helpers.sh"

get_location() {
	local location
	location=$(get_tmux_option "@weather-location" "")
	if [ -n "$location" ]; then
		geocode=$(curl -s "https://geocoding-api.open-meteo.com/v1/search?name=$location&count=1")
		latitude=$(echo $geocode | jq -r '.results[0].latitude')
		longitude=$(echo $geocode | jq -r '.results[0].longitude')
		echo "$latitude $longitude"
		return
	fi

	local location
	location=$(curl -s https://ipinfo.io/ 2>/dev/null)
	#city=$(echo $location | jq -r '.city')
	#region=$(echo $location | jq -r '.region')
	latitude=$(echo "$location" | jq -r '.loc' | cut -d ',' -f 1)
	longitude=$(echo "$location" | jq -r '.loc' | cut -d ',' -f 2)
	[ -n "$location" ] && echo "$latitude $longitude" && return

	echo "unknown"
}

get_weather() {
	local latitude=$1
	local longitude=$2
	local max_retries=3
	local retry_count=0

	if [ -z "$latitude" ] || [ -z "$longitude" ]; then
		echo "Latitude and longitude are required."
		return 1
	fi

	while [ $retry_count -lt $max_retries ]; do
		local response=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,is_day,cloud_cover,percipitation,rain&temperature_unit=fahrenheit")

		if [ -z "$response" ]; then
			retry_count=$((retry_count + 1))
			echo "Could not get weather data. Retrying..."
			sleep 2
		else
			echo "$response"
			return 0
		fi
	done

	if [ -z "$response" ]; then
		echo "Could not get weather data after $max_retries retries."
		return 1
	fi

}

get_cached_weather() {
	local latitude=$1
	local longitude=$2
	local cache_duration=$(get_tmux_option @forecast-cache-duration 0)                                  # in seconds, by default cache is disabled
	local cache_path=$(get_tmux_option @forecast-cache-path "/tmp/.weather-$latitude\_$longitude.json") # where to store the cached data
	local cache_file_age=$(get_file_age "$cache_path")
	local weather_data
	if [ "$cache_duration" -gt 0 ]; then
		if ! [ -f "$cache_path" ] || [ "$cache_file_age" -ge "$cache_duration" ]; then
			weather_data=$(get_weather)
			mkdir -p "$(dirname "$cache_path")"
			echo "$weather_data" >"$cache_path"
		else
			weather_data=$(cat "$cache_path" 2>/dev/null)
		fi
	else
		weather_data=$(get_weather)
	fi
	echo "$weather_data"
}

unpack() {
	local weather_data=$(get_cached_weather)
	local temperature=$(echo $weather_data | jq -r '.current.temperature_2m')
	local is_day=$(echo $weather_data | jq -r '.current.is_day')
	local cloud_cover=$(echo $weather_data | jq -r '.current.cloud_cover')
	local percipitation=$(echo $weather_data | jq -r '.current.percipitation')
	local rain=$(echo $weather_data | jq -r '.current.rain')
	echo "$temperature $is_day $cloud_cover $percipitation $rain"
}

weather_symbol() {
	local is_day=$1
	local cloud_cover=$2
	local percipitation=$3
	local rain=$4
	if [ "$is_day" == "1" ]; then
		if [ "$percipitation" == "1" ]; then
			if [ "$rain" == "1" ]; then
				echo "🌧️"
			else
				echo "🌦️"
			fi
		else
			if [ "$cloud_cover" -gt 50 ]; then
				echo "☁️"
			else
				echo "☀️"
			fi
		fi
	else
		if [ "$percipitation" == "1" ]; then
			if [ "$rain" == "1" ]; then
				echo "🌧️"
			else
				echo "🌦️"
			fi
		else
			echo "🌙"
		fi
	fi
}

main() {
	local location=$(get_location)
	local latitude=$(echo $location | cut -d ' ' -f 1)
	local longitude=$(echo $location | cut -d ' ' -f 2)
	local weather_data=$(get_cached_weather "$latitude" "$longitude")
	local unpacked_data=$(unpack "$weather_data")
	local temperature=$(echo $unpacked_data | cut -d ' ' -f 1)
	local is_day=$(echo $unpacked_data | cut -d ' ' -f 2)
	local cloud_cover=$(echo $unpacked_data | cut -d ' ' -f 3)
	local percipitation=$(echo $unpacked_data | cut -d ' ' -f 4)
	local rain=$(echo $unpacked_data | cut -d ' ' -f 5)
	local symbol=$(weather_symbol "$is_day" "$cloud_cover" "$percipitation" "$rain")
	echo "$symbol $temperature°F"
}

main
