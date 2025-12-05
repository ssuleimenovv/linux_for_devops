HEAD
set -e  # Остановить выполнение при ошибке

# echo "=== Step 1: Updating system packages ==="
sudo apt update -y && sudo apt upgrade -y

# echo "=== Step 2: Installing base tools ==="
sudo apt install -y git curl make ufw golang-go

# echo "=== Step 3: Configuring Go workspace ==="

#!/bin/bash
set -e  # Остановить выполнение при ошибке

echo "=== Step 1: Updating system packages ==="
sudo apt update -y && sudo apt upgrade -y

echo "=== Step 2: Installing base tools ==="
sudo apt install -y git curl make ufw golang-go

echo "=== Step 3: Configuring Go workspace ==="
d105bad427f38f8c01167c4c7073e3249c769036
mkdir -p ~/go_projects/sis3_project
cd ~/go_projects/sis3_project

export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

HEAD
# echo "=== Step 4: Initializing Go module ==="
go mod init sis3_project

# echo "=== Step 5: Installing Go libraries ==="
echo "=== Step 4: Initializing Go module ==="
go mod init sis3_project

echo "=== Step 5: Installing Go libraries ==="
d105bad427f38f8c01167c4c7073e3249c769036
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go get github.com/gin-gonic/gin
go get gorm.io/gorm
go get gorm.io/driver/sqlite
go get github.com/joho/godotenv

HEAD
# echo "=== Step 6: Setting up firewall ==="


echo "=== Step 6: Setting up firewall ==="
d105bad427f38f8c01167c4c7073e3249c769036
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 8080/tcp
sudo ufw allow 5432/tcp
sudo ufw status

HEAD
# echo "=== Step 7: Creating test Go server ==="

echo "=== Step 7: Creating test Go server ==="
d105bad427f38f8c01167c4c7073e3249c769036
cat <<'EOF' > main.go
package main

import (
    "fmt"
    "github.com/gin-gonic/gin"
    "gorm.io/driver/sqlite"
    "gorm.io/gorm"
)

func main() {
    fmt.Println("Running smoke test...")

    // Проверка GORM
    db, err := gorm.Open(sqlite.Open("test.db"), &gorm.Config{})
    if err != nil {
        panic("❌ Database connection failed")
    }

    // Используем db, чтобы избежать ошибки "declared and not used"
    sqlDB, err := db.DB()
    if err != nil {
        panic("❌ Failed to get generic database object")
    }
    defer sqlDB.Close()

    fmt.Println("✅ GORM connected successfully")

    // Проверка Gin
    r := gin.Default()
    r.GET("/", func(c *gin.Context) {
        c.JSON(200, gin.H{"message": "Smoke test passed!"})
    })

    fmt.Println("✅ Gin server running at http://localhost:8080")
    r.Run(":8080")
}
EOF

HEAD
# echo "=== Step 8: Building Go server ==="
go mod tidy
go build -o app main.go

# echo "=== Step 9: Running smoke test ==="

echo "=== Step 8: Building Go server ==="
go mod tidy
go build -o app main.go

echo "=== Step 9: Running smoke test ==="
d105bad427f38f8c01167c4c7073e3249c769036
./app &
APP_PID=$!
sleep 3
curl -s http://localhost:8080 | grep "Smoke test passed" && echo "✅ Smoke test OK" || echo "❌ Smoke test failed"

HEAD
# echo "=== Step 10: Cleanup ==="

echo "=== Step 10: Cleanup ==="
d105bad427f38f8c01167c4c7073e3249c769036
kill $APP_PID 2>/dev/null || true

echo "=== ✅ Environment setup completed successfully ==="
