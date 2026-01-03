#!/bin/bash
set -e

echo "=========================================="
echo "🔧 Configuring PostgreSQL Server Settings"
echo "=========================================="

CONF_FILE="/var/lib/postgresql/data/pgdata/postgresql.conf"

if [ ! -f "$CONF_FILE" ]; then
    echo "⚠️  Warning: $CONF_FILE not found!"
    exit 1
fi

# Backup original configuration
cp "$CONF_FILE" "${CONF_FILE}.bak"
echo "✓ Backed up original postgresql.conf"

# Configure PostgreSQL to listen on all network interfaces
# Default is 'localhost' which only allows local connections
echo "" >> "$CONF_FILE"
echo "# ==========================================" >> "$CONF_FILE"
echo "# External Access Configuration" >> "$CONF_FILE"
echo "# Added by init script: 03-configure-postgresql.sh" >> "$CONF_FILE"
echo "# ==========================================" >> "$CONF_FILE"
echo "listen_addresses = '*'  # Listen on all network interfaces" >> "$CONF_FILE"

echo "✓ Updated postgresql.conf to listen on all interfaces"
echo ""
echo "📋 Configuration added:"
echo "----------------------------------------"
tail -5 "$CONF_FILE"
echo "----------------------------------------"

echo ""
echo "ℹ️  PostgreSQL will bind to 0.0.0.0:5432 when container starts"
echo "✅ Server configuration completed!"
echo "=========================================="
