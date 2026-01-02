#!/bin/bash
# One-time fix script to create karaoke_user on existing database
# This replicates what the init script would have done on first startup

set -e

echo "=========================================="
echo "Fixing karaoke_user on existing database"
echo "=========================================="

# Get the password from environment or use default
KARAOKE_PASSWORD="${KARAOKE_DB_PASSWORD:-karaoke_password_secure_123}"

echo "Step 1: Checking if karaoke_user exists..."
USER_EXISTS=$(docker exec challenger_postgres psql -U challenger_user -d postgres -tAc \
    "SELECT 1 FROM pg_catalog.pg_user WHERE usename = 'karaoke_user';")

if [ "$USER_EXISTS" = "1" ]; then
    echo "✓ User karaoke_user exists"
    echo "Step 2: Updating password for karaoke_user..."
    docker exec challenger_postgres psql -U challenger_user -d postgres -c \
        "ALTER USER karaoke_user WITH PASSWORD '$KARAOKE_PASSWORD';"
    echo "✓ Password updated"
else
    echo "User karaoke_user does not exist"
    echo "Step 2: Creating karaoke_user..."
    docker exec challenger_postgres psql -U challenger_user -d postgres -c \
        "CREATE USER karaoke_user WITH PASSWORD '$KARAOKE_PASSWORD';"
    echo "✓ User created"
fi

echo "Step 3: Ensuring karaoke_db exists..."
DB_EXISTS=$(docker exec challenger_postgres psql -U challenger_user -d postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname = 'karaoke_db';")

if [ "$DB_EXISTS" != "1" ]; then
    echo "Creating karaoke_db..."
    docker exec challenger_postgres psql -U challenger_user -d postgres -c \
        "CREATE DATABASE karaoke_db OWNER karaoke_user ENCODING 'UTF8';"
    echo "✓ Database created"
else
    echo "✓ Database karaoke_db exists"
    echo "Step 4: Setting correct owner..."
    docker exec challenger_postgres psql -U challenger_user -d postgres -c \
        "ALTER DATABASE karaoke_db OWNER TO karaoke_user;"
    echo "✓ Owner updated"
fi

echo "Step 5: Granting all privileges..."
docker exec challenger_postgres psql -U challenger_user -d postgres -c \
    "GRANT ALL PRIVILEGES ON DATABASE karaoke_db TO karaoke_user;"
echo "✓ Privileges granted"

echo ""
echo "=========================================="
echo "Testing connection..."
echo "=========================================="
docker exec challenger_postgres psql -U karaoke_user -d karaoke_db -c \
    "SELECT current_database(), current_user, 'SUCCESS' as status;"

echo ""
echo "=========================================="
echo "✓ Fix completed successfully!"
echo "=========================================="