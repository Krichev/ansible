#!/bin/bash
set -e

echo "=========================================="
echo "🔧 Configuring PostgreSQL HBA (Host-Based Authentication)"
echo "=========================================="

# Backup original pg_hba.conf before modification
HBA_FILE="/var/lib/postgresql/data/pgdata/pg_hba.conf"
BACKUP_FILE="${HBA_FILE}.bak"

if [ -f "$HBA_FILE" ]; then
    cp "$HBA_FILE" "$BACKUP_FILE"
    echo "✓ Backed up original pg_hba.conf to pg_hba.conf.bak"
else
    echo "⚠️  Warning: $HBA_FILE not found!"
    exit 1
fi

# Add rules to allow external connections
# ⚠️ SECURITY WARNING: 0.0.0.0/0 allows connections from ANY IP address
# This is acceptable for DEVELOPMENT environments only!
#
# For PRODUCTION, replace with specific IP ranges:
#   host    all    all    192.168.1.0/24      scram-sha-256
#   host    all    all    YOUR_OFFICE_IP/32   scram-sha-256
#   host    all    all    10.0.0.0/8          scram-sha-256

cat >> "$HBA_FILE" << 'HBA'

# ==========================================
# External Connection Rules
# Added by init script: 02-custom-hba.sh
# ==========================================
# ⚠️  DEVELOPMENT ONLY - Restrict to specific IPs in production!

# Allow IPv4 connections from any address
host    all             all             0.0.0.0/0               scram-sha-256

# Allow IPv6 connections from any address
host    all             all             ::/0                    scram-sha-256

HBA

echo "✓ Updated pg_hba.conf with external connection rules"
echo ""
echo "📋 Current pg_hba.conf rules:"
echo "----------------------------------------"
tail -10 "$HBA_FILE"
echo "----------------------------------------"

# Reload PostgreSQL configuration without restart
echo ""
echo "🔄 Reloading PostgreSQL configuration..."
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT pg_reload_conf();" > /dev/null
echo "✓ PostgreSQL configuration reloaded successfully"

echo ""
echo "✅ HBA configuration completed!"
echo "=========================================="
