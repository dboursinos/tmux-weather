#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$CURRENT_DIR/helpers.sh"

get_location() {
	local location
	local coordinates_cache_file=$(get_tmux_option "@weather-coordinates-cache-file" "/tmp/.city-coordinates.json")
	local location=$(get_tmux_option "@weather-location" "")
	if [ -n "$location" ]; then
		if [ -f "$coordinates_cache_file" ]; then
			local latitude=$(jq -r --arg location "$location" '.location[$location].latitude' "$coordinates_cache_file")
			local longitude=$(jq -r --arg location "$location" '.location[$location].longitude' "$coordinates_cache_file")
			local cached_coordinates="$latitude $longitude"
			if [ -n "$latitude" ] && [ -n "$longitude" ]; then
				echo "$cached_coordinates"
				return
			fi
		fi
		geocode=$(curl -s "https://geocoding-api.open-meteo.com/v1/search?name=$location&count=1")
		latitude=$(echo $geocode | jq -r '.results[0].latitude')
		longitude=$(echo $geocode | jq -r '.results[0].longitude')

		# Update the cache file with the new coordinates
		if [ -f "$coordinates_cache_file" ]; then
			# if the location is not in the cache file, add it
			local location_in_cache=$(jq -r --arg location "$location" '.location | has($location)' "$coordinates_cache_file")
			if [ "$location_in_cache" == "false" ]; then
				jq --arg location "$location" --arg latitude "$latitude" --arg longitude "$longitude" '.location += {$location: {"latitude": $latitude, "longitude": $longitude}}' "$coordinates_cache_file" >"$coordinates_cache_file.tmp"
				mv "${coordinates_cache_file}.tmp" "${coordinates_cache_file}" --force
			fi
		else
			echo '{"location": {' >>"$coordinates_cache_file"
			echo "  \"$location\": {\"latitude\": \"$latitude\", \"longitude\": \"$longitude\"}" >>"$coordinates_cache_file"
			echo '}}' >>"$coordinates_cache_file"
		fi
		echo "$latitude $longitude"
		return
	fi

	local cache_location_duration_minutes=$(get_tmux_option @weather-location-interval 240) # in minutes
	if [ "$cache_location_duration_minutes" -lt 120 ]; then
		cache_location_duration_minutes=120
	fi
	local cache_location_duration=$((cache_location_duration_minutes * 60))
	local cache_location_path=$(get_tmux_option @weather-location-cache-path "/tmp/.weather-location.json")
	local cache_file_age=$(get_file_age "$cache_location_path")
	# TODO: The external if statement is not needed anymore
	if [ "$cache_location_duration" -gt 0 ]; then
		if ! [ -f "$cache_location_path" ] || [ "$cache_file_age" -ge "$cache_location_duration" ]; then
			location=$(curl -s https://ipinfo.io/ 2>/dev/null)
			mkdir -p "$(dirname "$cache_location_path")"
			echo $location >"$cache_location_path"
		else
			location=$(cat "$cache_location_path" 2>/dev/null)
		fi
	else
		location=$(curl -s https://ipinfo.io/ 2>/dev/null)
	fi

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

	local show_fahrenheit=$(get_tmux_option "@weather-show-fahrenheit" "true")
	while [ $retry_count -lt $max_retries ]; do
		if [ "$show_fahrenheit" == "false" ]; then
			local response=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,is_day,precipitation,cloud_cover,rain")
		else
			local response=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,is_day,cloud_cover,precipitation,rain&temperature_unit=fahrenheit")
		fi

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
	local cache_duration_minutes=$(get_tmux_option @weather-interval 15) # in seconds, by default cache is disabled
	if [ "$cache_duration_minutes" -lt 5 ]; then
		cache_duration_minutes=5
	fi
	local cache_duration=$((cache_duration_minutes * 60))
	local cache_path=$(get_tmux_option @weather-cache-path "/tmp/.weather-$latitude\_$longitude.json") # where to store the cached data
	local cache_file_age=$(get_file_age "$cache_path")
	local weather_data
	if [ "$cache_duration" -gt 0 ]; then
		if ! [ -f "$cache_path" ] || [ "$cache_file_age" -ge "$cache_duration" ]; then
			weather_data=$(get_weather $latitude $longitude)
			mkdir -p "$(dirname "$cache_path")"
			echo $weather_data >"$cache_path"
		else
			weather_data=$(cat "$cache_path" 2>/dev/null)
		fi
	else
		weather_data=$(get_weather $latitude $longitude)
	fi
	echo "$weather_data"
}

unpack() {
	local weather_data=$(get_cached_weather "$(get_location)")
	local temperature=$(echo $weather_data | jq -r '.current.temperature_2m')
	local is_day=$(echo $weather_data | jq -r '.current.is_day')
	local cloud_cover=$(echo $weather_data | jq -r '.current.cloud_cover')
	local percipitation=$(echo $weather_data | jq -r '.current.percipitation')
	local rain=$(echo $weather_data | jq -r '.current.rain')
	echo "$temperature $is_day $cloud_cover $rain"
}

weather_symbol() {
	local is_day=$1
	local cloud_cover=$2
	local percipitation=$3
	local rain=$4

	# Weather icons from https://www.nerdfonts.com/cheat-sheet
	# Possible TODO: Add more weather icons
	#declare -A weather_icons=(
	#["Clear"]="󰖙"
	#["Cloud"]=""
	#["Drizzle"]="󰖗"
	#["Fog"]=""
	#["Haze"]="󰼰"
	#["Mist"]=""
	#["Overcast"]=""
	#["Rain"]=""
	#["Sand"]=""
	#["Shower"]=""
	#["Smoke"]=""
	#["Snow"]=""
	#["Sunny"]="󰖙"
	#["Thunderstorm"]=""
	#["Tornado"]="󰼸"
	#["Windy"]="󰖝"
	#)

	# TODO:
	# Add partial cloud cover ⛅️/🌤️
	# Add partial rain 🌦️
	# Add snow ❄️
	# Reorganize the if statements
	if [ "$is_day" == "1" ]; then
		if [ "$percipitation" -gt 0 ]; then
			if [ "$rain" -gt 0 ]; then
				echo "🌧️"
			else
				echo "🌦️"
			fi
		else
			if [ "$cloud_cover" -gt 20 ] && [ "$cloud_cover" -lt 50 ]; then
				echo "⛅️"
			elif [ "$cloud_cover" -gt 50 ]; then
				echo "☁️"
			else
				echo "☀️"
			fi
		fi
	else
		if [ "$cloud_cover" -gt 50 ]; then
			if [ "$rain" -gt 0 ]; then
				echo "🌧️"
			else
				echo "☁️"
			fi
		else
			echo "🌙"
		fi
	fi
}

main() {
	local weather_data=$(get_cached_weather "$(get_location)")
	local unpacked_data=$(unpack)
	local temperature=$(echo $unpacked_data | cut -d ' ' -f 1)
	local is_day=$(echo $unpacked_data | cut -d ' ' -f 2)
	local cloud_cover=$(echo $unpacked_data | cut -d ' ' -f 3)
	local percipitation=$(echo $unpacked_data | cut -d ' ' -f 4)
	local rain=$(echo $unpacked_data | cut -d ' ' -f 5)
	local symbol=$(weather_symbol "$is_day" "$cloud_cover" "$percipitation" "$rain")
	local show_fahrenheit=$(get_tmux_option "@weather-show-fahrenheit" "true")
	if [ "$show_fahrenheit" == "false" ]; then
		echo "${symbol} ${temperature}°C"
	else
		echo "${symbol} ${temperature}°F"
	fi
}

main
