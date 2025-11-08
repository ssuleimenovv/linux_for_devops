#!/bin/bash
set -euo pipefail

# === SIS4 Weather Service Project ===
# Author: Suleimenov Ayan
# Topic: Working with Services
# Target: Create and configure Linux services, containers, and scheduled scripts.

DOCKER_USER="ssuleimenovv"
AUTHOR="Suleimenov Ayan"
APP_NAME="weather_service"
IMAGE_TAG="v1"
PROJECT_DIR="$HOME/go_projects/sis4_weather"
SERVICE_NAME="weather.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
LOG_DIR="$HOME/weather_logs"
DATA_FILE="$LOG_DIR/weather.json"
CSV_FILE="$LOG_DIR/weather_log.csv"

UPDATE_SCRIPT="/usr/local/bin/update_weather.sh"
LOG_SCRIPT="/usr/local/bin/log_weather.sh"
CLEAN_SCRIPT="/usr/local/bin/cleanup_weather.sh"

echo "=== Weather Service setup by $AUTHOR ==="

# 0️⃣ Cleanup (safe re-run)
echo "[0] Cleaning up old configs..."
sudo systemctl stop $SERVICE_NAME 2>/dev/null || true
sudo systemctl disable $SERVICE_NAME 2>/dev/null || true
sudo docker stop weather_container 2>/dev/null || true
sudo docker rm weather_container 2>/dev/null || true
sudo docker rmi -f $DOCKER_USER/$APP_NAME:$IMAGE_TAG 2>/dev/null || true
sudo rm -f $SERVICE_FILE 2>/dev/null || true
sudo crontab -r 2>/dev/null || true

# 1️⃣ Install dependencies
echo "Docker already installed - skipping reinstallation"
sudo apt install -y curl jq golang-go

# 2️⃣ Create Go weather app
echo "[2] Creating Go weather app..."
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

cat > main.go <<'EOF'
package main

import (
    "fmt"
    "net/http"
    "os"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        data, err := os.ReadFile("/data/weather.json")
        if err != nil {
            http.Error(w, "No weather data found", 500)
            return
        }
        w.Header().Set("Content-Type", "application/json")
        w.Write(data)
    })

    fmt.Println("🌤️ Weather service running on http://localhost:8080")
    http.ListenAndServe(":8080", nil)
}
EOF

go mod init weather_service 2>/dev/null || true
go mod tidy
go build -o $APP_NAME

# 3️⃣ Dockerfile
echo "[3] Creating Dockerfile..."
cat > Dockerfile <<EOF
FROM golang:1.22-alpine
WORKDIR /app
COPY . .
RUN go build -o $APP_NAME
EXPOSE 8080
VOLUME /data
CMD ["./$APP_NAME"]
EOF

# 4️⃣ Build and push Docker image
echo "[4] Building and pushing Docker image..."
docker build -t $DOCKER_USER/$APP_NAME:$IMAGE_TAG .
echo "[Docker login required]"
docker login
docker push $DOCKER_USER/$APP_NAME:$IMAGE_TAG

# 5️⃣ Create systemd service
echo "[5] Creating systemd service..."
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Weather Service Container
After=network.target docker.service
Requires=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker run --rm -p 8080:8080 -v $LOG_DIR:/data --name weather_container $DOCKER_USER/$APP_NAME:$IMAGE_TAG
ExecStop=/usr/bin/docker stop weather_container
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now $SERVICE_NAME
sleep 3
sudo systemctl status $SERVICE_NAME --no-pager | sed -n '1,10p'

# 6️⃣ Create logs and weather data
echo "[6] Preparing logs and initial data..."
mkdir -p "$LOG_DIR"
echo '{"temp":25,"condition":"sunny","updated":"initial"}' > "$DATA_FILE"
echo "timestamp,temp,condition" > "$CSV_FILE"

# 7️⃣ Script 1 — update_weather.sh
echo "[7] Creating update_weather.sh..."
sudo bash -c "cat > $UPDATE_SCRIPT" <<'EOF'
#!/bin/bash
LOG_DIR="$HOME/weather_logs"
DATA_FILE="$LOG_DIR/weather.json"

# Simulated weather update (can be replaced with real API)
TEMP=$((15 + RANDOM % 15))
CONDITIONS=("sunny" "cloudy" "rainy" "windy" "stormy")
COND=${CONDITIONS[$RANDOM % ${#CONDITIONS[@]}]}
TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -n --argjson temp "$TEMP" --arg cond "$COND" --arg time "$TIME" \
  '{temp: $temp, condition: $cond, updated: $time}' > "$DATA_FILE"
EOF
sudo chmod +x "$UPDATE_SCRIPT"

# 8️⃣ Script 2 — log_weather.sh
echo "[8] Creating log_weather.sh..."
sudo bash -c "cat > $LOG_SCRIPT" <<'EOF'
#!/bin/bash
LOG_DIR="$HOME/weather_logs"
DATA_FILE="$LOG_DIR/weather.json"
CSV_FILE="$LOG_DIR/weather_log.csv"

if [ ! -f "$DATA_FILE" ]; then
  echo "$(date): no weather data" >> "$LOG_DIR/error.log"
  exit 1
fi

TEMP=$(jq '.temp' "$DATA_FILE")
COND=$(jq -r '.condition' "$DATA_FILE")
TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "$TIME,$TEMP,$COND" >> "$CSV_FILE"
EOF
sudo chmod +x "$LOG_SCRIPT"

# 9️⃣ Script 3 — cleanup_weather.sh
echo "[9] Creating cleanup_weather.sh..."
sudo bash -c "cat > $CLEAN_SCRIPT" <<'EOF'
#!/bin/bash
LOG_DIR="$HOME/weather_logs"
find "$LOG_DIR" -type f -name "*.csv" -mtime +7 -delete
EOF
sudo chmod +x "$CLEAN_SCRIPT"

# 🔟 Schedule cron jobs
echo "[10] Setting up cron jobs..."
( sudo crontab -l 2>/dev/null || true; \
  echo "*/5 * * * * $UPDATE_SCRIPT"; \
  echo "*/10 * * * * $LOG_SCRIPT"; \
  echo "0 3 * * * $CLEAN_SCRIPT" ) | sudo crontab -

# ✅ Final checks
echo "[11] Checking status..."
sudo systemctl is-active $SERVICE_NAME
curl -s http://localhost:8080 | jq
sudo crontab -l

echo "=== Weather Service setup complete ==="
echo " - Docker image: $DOCKER_USER/$APP_NAME:$IMAGE_TAG"
echo " - Service: $SERVICE_NAME (auto-restart enabled)"
echo " - Cron jobs installed:"
echo "     $UPDATE_SCRIPT — every 5 min"
echo "     $LOG_SCRIPT — every 10 min"
echo "     $CLEAN_SCRIPT — daily at 3 AM"
echo " - Logs directory: $LOG_DIR"
