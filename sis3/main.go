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

echo "=== Step 8: Building Go server ==="
go mod tidy
go build -o app main.go

echo "=== Step 9: Running smoke test ==="
./app &
sleep 3
curl -s http://localhost:8080 | grep "Smoke test passed" && echo "✅ Smoke test OK" || echo "❌ Smoke test failed"

echo "=== Step 10: Cleanup ==="
kill $(lsof -t -i:8080) 2>/dev/null || true

echo "=== ✅ Environment setup completed successfully ==="