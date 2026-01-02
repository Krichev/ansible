#!/bin/bash
# Idempotent script to ensure karaoke_user exists with correct password
# Can be run multiple times safely

set -e

echo "=========================================="
echo "Ensuring karaoke_user setup is correct"
echo "=========================================="

# Get the password from environment or use default
KARAOKE_PASSWORD="${KARAOKE_DB_PASSWORD:-karaoke_password_secure_123}"

echo "Step 1: Checking if karaoke_user exists..."
USER_EXISTS=$(docker exec challenger_postgres psql -U challenger_user -d postgres -tAc \
    "SELECT 1 FROM pg_catalog.pg_user WHERE usename = 'karaoke_user';" || echo "0")

if [ "$USER_EXISTS" = "1" ]; then
    echo "✓ User karaoke_user exists"
    echo "Step 2: Updating password for karaoke_user..."
    docker exec challenger_postgres psql -U challenger_user -d postgres -c \
        "ALTER USER karaoke_user WITH PASSWORD '$KARAOKE_PASSWORD';"
    echo "✓ Password updated"
else
    echo "User karaoke_user does not exist"
    echo "Step 2: Creating karaoke_user and database..."
    
    docker exec -i challenger_postgres \
      psql -U challenger_user -d postgres <<EOSQL
CREATE USER karaoke_user WITH PASSWORD '$KARAOKE_PASSWORD';
CREATE DATABASE karaoke_db
  OWNER karaoke_user
  ENCODING 'UTF8';
GRANT ALL PRIVILEGES ON DATABASE karaoke_db TO karaoke_user;
EOSQL
    
    echo "✓ User and database created"
fi

echo "Step 3: Verifying database exists..."
DB_EXISTS=$(docker exec challenger_postgres psql -U challenger_user -d postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname = 'karaoke_db';" || echo "0")

if [ "$DB_EXISTS" != "1" ]; then
    echo "Database doesn't exist, creating..."
    docker exec challenger_postgres psql -U challenger_user -d postgres -c \
        "CREATE DATABASE karaoke_db OWNER karaoke_user ENCODING 'UTF8';"
    echo "✓ Database created"
else
    echo "✓ Database karaoke_db exists"
fi

echo "Step 4: Ensuring correct ownership and privileges..."
docker exec challenger_postgres psql -U challenger_user -d postgres -c \
    "ALTER DATABASE karaoke_db OWNER TO karaoke_user;"
docker exec challenger_postgres psql -U challenger_user -d postgres -c \
    "GRANT ALL PRIVILEGES ON DATABASE karaoke_db TO karaoke_user;"
echo "✓ Ownership and privileges set"

echo ""
echo "=========================================="
echo "Testing connection..."
echo "=========================================="
docker exec challenger_postgres psql -U karaoke_user -d karaoke_db -c \
    "SELECT current_database(), current_user, version();" || {
    echo "ERROR: Connection test failed!"
    exit 1
}

echo ""
echo "=========================================="
echo "✓ Setup completed successfully!"
echo "=========================================="
