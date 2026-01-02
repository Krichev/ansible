#!/bin/bash
set -e

echo "=== Karaoke User Fix Script ==="
echo "This script creates karaoke_user and karaoke_db if they don't exist"

# Get password from environment or use default
KARAOKE_PASSWORD="${KARAOKE_DB_PASSWORD:-karaoke_password_dev_123}"

# Execute SQL commands inside the PostgreSQL container
docker exec -i challenger_postgres psql -U challenger_user -d postgres <<-EOSQL
    -- Create karaoke user if doesn't exist
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'karaoke_user') THEN
            CREATE USER karaoke_user WITH PASSWORD '${KARAOKE_PASSWORD}';
            RAISE NOTICE 'User karaoke_user created';
        ELSE
            RAISE NOTICE 'User karaoke_user already exists';
        END IF;
    END
    \$\$;

    -- Create karaoke database if doesn't exist
    SELECT 'CREATE DATABASE karaoke_db OWNER karaoke_user ENCODING UTF8'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'karaoke_db')\gexec

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE karaoke_db TO karaoke_user;

    -- Ensure ownership is correct
    ALTER DATABASE karaoke_db OWNER TO karaoke_user;
EOSQL

echo "=== Karaoke user fix completed ==="
