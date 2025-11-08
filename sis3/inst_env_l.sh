#!/bin/bash
set -e  # Остановить выполнение при ошибке

echo "=== Step 1: Updating system packages ==="
sudo apt update -y && sudo apt upgrade -y

echo "=== Step 2: Installing base tools ==="
sudo apt install -y git curl make ufw golang-go

echo "=== Step 3: Configuring Go workspace ==="
mkdir -p ~/go_projects/sis3_project
cd ~/go_projects/sis3_project

export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

echo "=== Step 4: Initializing Go module (if needed) ==="
if [ ! -f go.mod ]; then
    go mod init sis3_project
else
    echo "✅ go.mod уже существует — пропускаю инициализацию."
fi

echo "=== Step 5: Creating main.go (if missing) ==="
if [ ! -f main.go ]; then
cat <<'EOF' > main.go
package main

import (
    "fmt"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "Smoke test passed")
    })

    fmt.Println("✅ Server running on http://localhost:8080")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        panic(err)
    }
}
EOF
else
    echo "✅ main.go уже существует — пропускаю создание."
fi

echo "=== Step 6: Tidying modules ==="
go mod tidy

echo "=== Step 7: Building the application ==="
go build -o sis3_app

echo "=== Step 8: Running app in background ==="
nohup ./sis3_app > app.log 2>&1 &

echo "=== Step 9: Running smoke test ==="

echo "Checking all imports"
REQUIRED_LIBS=("fmt" "net/http")

for lib in "${REQUIRED_LIBS[@]}"; do
  if go list std | grep -q "^$lib$"; then
    echo "✅ lib $lib found (std)"
  else
    echo "❌ lib $lib not found"
    exit 1
  fi
done

sleep 2
curl -s http://localhost:8080 | grep "Smoke test passed" \
  && echo "✅ Smoke test OK" \
  || echo "❌ Smoke test failed"


echo "=== Done! ==="
