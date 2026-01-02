#!/bin/bash
set -e

echo "=== Creating karaoke database and user ==="

# Create karaoke user if doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create karaoke user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'karaoke_user') THEN
            CREATE USER karaoke_user WITH PASSWORD '${KARAOKE_DB_PASSWORD:-karaoke_password_dev_123}';
            RAISE NOTICE 'User karaoke_user created';
        ELSE
            RAISE NOTICE 'User karaoke_user already exists';
        END IF;
    END
    \$\$;

    -- Create karaoke database
    SELECT 'CREATE DATABASE karaoke_db OWNER karaoke_user ENCODING UTF8'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'karaoke_db')\gexec

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE karaoke_db TO karaoke_user;

    ALTER DATABASE karaoke_db OWNER TO karaoke_user;
EOSQL

echo "=== Karaoke database setup completed ==="
