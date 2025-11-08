#!/bin/bash

# === 🌤️ Weather Checker Script ===
# This script allows the user to check the current weather
# for any city by fetching data from the Open-Meteo API.

echo "=== 🌤️ Weather Checker ==="
echo "Enter a city name (example: Astana, Almaty, London):"
read CITY

# Get city coordinates using Open-Meteo Geocoding API
RESPONSE=$(curl -s "https://geocoding-api.open-meteo.com/v1/search?name=$CITY&count=1")

# Check if the city exists in API response
if [[ $(echo $RESPONSE | jq '.results | length') -eq 0 ]]; then
  echo "❌ City not found. Please try again."
  exit 1
fi

# Extract latitude and longitude from the JSON response
LAT=$(echo $RESPONSE | jq '.results[0].latitude')
LON=$(echo $RESPONSE | jq '.results[0].longitude')
NAME=$(echo $RESPONSE | jq -r '.results[0].name')

# Get current weather data using Open-Meteo API
WEATHER=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current_weather=true")

# Extract temperature and wind speed from the JSON response
TEMP=$(echo $WEATHER | jq '.current_weather.temperature')
WIND=$(echo $WEATHER | jq '.current_weather.windspeed')

# Display the results
echo "=== ☁️ Weather in $NAME ==="
echo "Temperature: $TEMP°C"
echo "Wind Speed: $WIND km/h"
