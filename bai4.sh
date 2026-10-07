#!/bin/bash
set -e

echo "=========================================="
echo "1. Tạo Custom Bridge Network: app-net"
echo "=========================================="
docker network create app-net || true

echo "=========================================="
echo "2. Tạo Named Volume: db-data"
echo "=========================================="
docker volume create db-data || true

echo "=========================================="
echo "3. Khởi chạy Database Container (db-server)"
echo "=========================================="
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_DB=appdb \
  postgres:15-alpine

echo "=========================================="
echo "4. Khởi chạy Backend Container (app-container)"
echo "=========================================="
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=appdb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=mysecretpassword \
  alpine sleep infinity

echo "Đang chờ PostgreSQL khởi động hoàn toàn..."
sleep 5

echo "=========================================="
echo "5. Thực hiện test Data Persistence: Thêm dữ liệu"
echo "=========================================="
docker exec -i db-server psql -U postgres -d appdb -c "CREATE TABLE IF NOT EXISTS test_data (id SERIAL PRIMARY KEY, value VARCHAR(100));"
docker exec -i db-server psql -U postgres -d appdb -c "INSERT INTO test_data (value) VALUES ('Data persisted successfully!');"

echo "Dữ liệu trước khi xóa container DB:"
docker exec -i db-server psql -U postgres -d appdb -c "SELECT * FROM test_data;"

echo "=========================================="
echo "6. Xóa cứng container DB (docker rm -f db-server)"
echo "=========================================="
docker rm -f db-server

echo "=========================================="
echo "7. Khởi chạy lại container DB mới gắn cùng Volume db-data"
echo "=========================================="
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_DB=appdb \
  postgres:15-alpine

echo "Đang chờ PostgreSQL mới khởi động..."
sleep 5

echo "=========================================="
echo "8. Xác minh dữ liệu không bị mất"
echo "=========================================="
docker exec -i db-server psql -U postgres -d appdb -c "SELECT * FROM test_data;"

echo "=========================================="
echo "9. Kiểm tra kết nối DNS giữa Backend Container và DB Server"
echo "=========================================="
docker exec -it app-container ping -c 2 db-server

echo "Tất cả các bước đã hoàn thành thành công!"