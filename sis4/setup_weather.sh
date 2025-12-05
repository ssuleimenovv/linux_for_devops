#!/bin/bash
set -e

APP_NAME="weather_city_selector"
APP_DIR="$HOME/${APP_NAME}"
DOCKER_USER="ayan"
IMAGE_TAG="v1.0"
SERVICE_NAME="${APP_NAME}.service"
LOG_DIR="$HOME/${APP_NAME}_logs"
UPDATE_SCRIPT="$APP_DIR/update_city_weather.sh"
LOG_SCRIPT="$APP_DIR/log_city_weather.sh"
CLEAN_SCRIPT="$APP_DIR/cleanup_city_weather.sh"

echo "=== Weather City Selector Setup by Suleimenov Ayan ==="

# ==============================
# [1] Install dependencies
# ==============================
echo "[1] Installing dependencies..."
sudo apt update -y
sudo apt install -y golang-go jq curl ca-certificates gnupg lsb-release

# Check Docker
if ! command -v docker &> /dev/null
then
    echo "[1a] Docker not found. Installing official Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin containerd.io
fi

sudo systemctl enable --now docker
docker --version

# ==============================
# [2] Project structure
# ==============================
echo "[2] Setting up project directories..."
mkdir -p "$APP_DIR" "$LOG_DIR"

# ==============================
# [3] Go app
# ==============================
echo "[3] Creating Go weather fetcher..."
cat > "$APP_DIR/main.go" <<'EOF'
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

type Weather struct {
	CurrentCondition []struct {
		TempC       string `json:"temp_C"`
		WeatherDesc []struct {
			Value string `json:"value"`
		} `json:"weatherDesc"`
	} `json:"current_condition"`
}

func fetchWeather(city string) (map[string]string, error) {
	url := fmt.Sprintf("https://wttr.in/%s?format=j1", city)
	resp, err := http.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	var data Weather
	json.Unmarshal(body, &data)
	if len(data.CurrentCondition) == 0 {
		return nil, fmt.Errorf("invalid city or API error")
	}
	temp := data.CurrentCondition[0].TempC
	desc := data.CurrentCondition[0].WeatherDesc[0].Value
	timeNow := time.Now().UTC().Format(time.RFC3339)
	return map[string]string{
		"city":      city,
		"temp":      temp,
		"condition": desc,
		"updated":   timeNow,
	}, nil
}

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		city := r.URL.Query().Get("city")
		if city == "" {
			city = "Almaty"
		}
		data, err := fetchWeather(city)
		if err != nil {
			http.Error(w, "Failed to get weather", http.StatusInternalServerError)
			return
		}
		file, _ := os.Create("/app/weather_city.json")
		defer file.Close()
		json.NewEncoder(file).Encode(data)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(data)
	})
	fmt.Println("🌤️ Weather City Selector running on http://localhost:8081")
	http.ListenAndServe(":8081", nil)
}
EOF

# ==============================
# [4] Dockerfile
# ==============================
echo "[4] Creating Dockerfile..."
cat > "$APP_DIR/Dockerfile" <<'EOF'
FROM golang:1.22
WORKDIR /app
COPY main.go .
RUN go build -o weather_app main.go
EXPOSE 8081
CMD ["./weather_app"]
EOF

# ==============================
# [5] Build Docker image
# ==============================
echo "[5] Building Docker image..."
cd "$APP_DIR"
sudo docker build -t "$DOCKER_USER/$APP_NAME:$IMAGE_TAG" .

# ==============================
# [6] Systemd service
# ==============================
echo "[6] Creating systemd service..."
sudo bash -c "cat > /etc/systemd/system/$SERVICE_NAME" <<EOF
[Unit]
Description=Weather City Selector Web Service
After=network.target

[Service]
ExecStart=/usr/bin/docker run --rm -p 8081:8081 -v $LOG_DIR:/app --name weather_city_container $DOCKER_USER/$APP_NAME:$IMAGE_TAG
HEAD
ExecStop=/usr/bin/docker stop weather_city_container

d105bad427f38f8c01167c4c7073e3249c769036
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME
sudo systemctl status $SERVICE_NAME --no-pager

# ==============================
# [7] Scripts
# ==============================
echo "[7] Creating update, log, and cleanup scripts..."

# --- Update ---
cat > "$UPDATE_SCRIPT" <<'EOF'
#!/bin/bash
APP_NAME="weather_city_selector"
LOG_DIR="$HOME/${APP_NAME}_logs"
CITY=${1:-Astana}
TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
curl -s "https://wttr.in/$CITY?format=j1" | jq ".current_condition[0] | {city: \"$CITY\", temp: .temp_C, condition: .weatherDesc[0].value, updated: \"$TIME\"}" > "$LOG_DIR/weather_city.json"
EOF
chmod +x "$UPDATE_SCRIPT"

# --- Log ---
cat > "$LOG_SCRIPT" <<'EOF'
#!/bin/bash
APP_NAME="weather_city_selector"
LOG_DIR="$HOME/${APP_NAME}_logs"
DATA_FILE="$LOG_DIR/weather_city.json"
CSV_FILE="$LOG_DIR/weather_city_log.csv"

if [ ! -f "$DATA_FILE" ]; then
  echo "$(date): no weather data" >> "$LOG_DIR/error.log"
  exit 1
fi

TEMP=$(jq -r '.temp' "$DATA_FILE")
COND=$(jq -r '.condition' "$DATA_FILE")
CITY=$(jq -r '.city' "$DATA_FILE")
TIME=$(jq -r '.updated' "$DATA_FILE")

echo "$TIME,$CITY,$TEMP,$COND" >> "$CSV_FILE"
EOF
chmod +x "$LOG_SCRIPT"

# --- Cleanup ---
cat > "$CLEAN_SCRIPT" <<'EOF'
#!/bin/bash
APP_NAME="weather_city_selector"
LOG_DIR="$HOME/${APP_NAME}_logs"
find "$LOG_DIR" -type f -name "*.csv" -mtime +7 -delete
EOF
chmod +x "$CLEAN_SCRIPT"

# ==============================
# [8] Cron jobs
# ==============================
echo "[8] Setting up cron jobs..."
( sudo crontab -l 2>/dev/null || true; \
  echo "*/5 * * * * $UPDATE_SCRIPT Astana"; \
  echo "*/10 * * * * $LOG_SCRIPT"; \
  echo "0 3 * * * $CLEAN_SCRIPT" ) | sudo crontab -

echo "=== Setup complete! ==="
echo "Web URL: http://localhost:8081?city=Paris"
echo "Manual update: bash $UPDATE_SCRIPT London"
echo "Logs directory: $LOG_DIR"
