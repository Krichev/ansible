# Ansible Utility Scripts

## Overview
This directory contains utility scripts that are **run manually** by Ansible playbooks on **existing** PostgreSQL containers.

## Key Differences from init-scripts/

| Aspect | init-scripts/ | scripts/ (this directory) |
|--------|---------------|---------------------------|
| **When runs** | Automatically on fresh container creation | Manually via Ansible playbooks |
| **Execution trigger** | Docker entrypoint | Ansible `command` or `shell` tasks |
| **Target** | Fresh PostgreSQL instances | Existing/running containers |
| **Location** | Inside container at `/docker-entrypoint-initdb.d/` | Copied to remote host by Ansible |
| **Use case** | Initial setup | Fixes, updates, maintenance |

## Scripts

### fix-karaoke-user.sh
**Purpose:** Creates or updates `karaoke_user` and `karaoke_db` on existing PostgreSQL containers

**When to use:**
- PostgreSQL container was created before `karaoke_user` existed
- Need to update `karaoke_user` password after deployment
- Karaoke database was accidentally deleted
- Container exists but init scripts didn't run (volume was reused)

**How it's used:**
Called by Ansible playbooks (`provision.yml`, `migrate.yml`):
```yaml
- name: Copy karaoke user fix script
  copy:
    src: scripts/fix-karaoke-user.sh
    dest: "{{ project_dir }}/postgres/fix-karaoke-user.sh"
    owner: "{{ system_user }}"
    group: "{{ system_user }}"
    mode: "0755"

- name: Run karaoke user setup script (idempotent)
  command: bash fix-karaoke-user.sh
  args:
    chdir: "{{ project_dir }}/postgres"
  environment:
    KARAOKE_DB_PASSWORD: "{{ karaoke_db_password }}"
```

**What it does:**
1. Checks if `karaoke_user` exists in PostgreSQL
2. If missing, creates the user with provided password
3. Creates `karaoke_db` database if it doesn't exist
4. Grants all privileges to `karaoke_user`
5. Ensures database ownership is correct

**Idempotency:**
- **Safe to run multiple times** - Uses `IF NOT EXISTS` checks
- Only creates resources that don't already exist
- Updates ownership even if resources exist

**Execution method:**
```bash
docker exec -i challenger_postgres psql -U challenger_user -d postgres <<-EOSQL
    -- SQL commands with idempotent checks
EOSQL
```

**Required environment variables:**
- `KARAOKE_DB_PASSWORD` - Password for `karaoke_user` (passed by Ansible)

**Output:**
```
=== Karaoke User Fix Script ===
This script creates karaoke_user and karaoke_db if they don't exist
NOTICE:  User karaoke_user created
=== Karaoke user fix completed ===
```

Or if user already exists:
```
NOTICE:  User karaoke_user already exists
```

---

## Usage Patterns

### Running via Ansible
Scripts in this directory are typically copied to the remote server and executed:

```bash
# From local machine
ansible-playbook -i inventory.ini provision.yml
```

This will:
1. Copy `fix-karaoke-user.sh` to `/opt/wwwquest/postgres/`
2. Execute it inside the running PostgreSQL container
3. Display output via Ansible debug tasks

### Manual Execution (SSH)
You can also run scripts manually after SSH-ing to the server:

```bash
# SSH to server
ssh user@your-server

# Navigate to project directory
cd /opt/wwwquest/postgres

# Run the fix script
KARAOKE_DB_PASSWORD="your_password" bash fix-karaoke-user.sh
```

**Important:** Always set the `KARAOKE_DB_PASSWORD` environment variable!

---

## When to Use Each Script Type

### Use init-scripts/ when:
- Setting up a **brand new** PostgreSQL instance
- You can destroy and recreate the database volume
- Configuring PostgreSQL server settings (authentication, networking)
- You want automated setup on fresh container creation

### Use scripts/ (this directory) when:
- Working with an **existing** PostgreSQL container
- Cannot destroy the database (production data exists)
- Fixing issues after initial deployment
- Updating configuration on running systems
- Applied changes need to work with existing data

---

## Adding New Utility Scripts

When creating new scripts for this directory:

1. **Make them idempotent** - Safe to run multiple times
2. **Use SQL checks** - `IF NOT EXISTS`, `DO $$` blocks
3. **Accept environment variables** - For passwords and configuration
4. **Add to Ansible playbooks** - Copy and execute via Ansible
5. **Document in this README** - Explain purpose and usage
6. **Set executable permissions** - `chmod +x script-name.sh`

**Example template:**
```bash
#!/bin/bash
set -e

echo "=== My Utility Script ==="

# Get configuration from environment
MY_VAR="${MY_VAR:-default_value}"

# Execute SQL with idempotent checks
docker exec -i challenger_postgres \
  psql -U challenger_user -d postgres <<'EOSQL'
DO $$
BEGIN
    IF NOT EXISTS (...) THEN
        -- Your changes here
    END IF;
END
$$;
EOSQL

echo "=== Script completed ==="
```

---

## Troubleshooting

### Script fails with "psql: connection refused"
**Cause:** PostgreSQL container is not running

**Solution:**
```bash
# Check container status
docker compose ps

# Start if stopped
docker compose up -d postgres
```

### Script fails with "FATAL: role does not exist"
**Cause:** Base `challenger_user` doesn't exist

**Solution:**
The PostgreSQL container wasn't initialized properly. Check:
```bash
# View PostgreSQL logs
docker compose logs postgres

# Check if init scripts ran
docker compose logs postgres | grep "init-scripts"
```

### Permission denied when executing script
**Cause:** Script is not executable

**Solution:**
```bash
# Make script executable
chmod +x ansible/scripts/fix-karaoke-user.sh
```

### Password authentication fails
**Cause:** Password in Ansible variable doesn't match database

**Solution:**
```bash
# Check current password in group_vars
cat ansible/group_vars/db.yml

# Update password in database using the fix script
ansible-playbook -i inventory.ini provision.yml
```

---

## Related Files

- `ansible/provision.yml` - Uses `fix-karaoke-user.sh` during provisioning
- `ansible/migrate.yml` - Ensures karaoke user exists before migrations
- `ansible/group_vars/db.yml` - Contains `karaoke_db_password` variable
- `ansible/docker/postgres/init-scripts/` - Automatic initialization scripts
- `ansible/docker/postgres/init-scripts/README.md` - Init scripts documentation

---

## Best Practices

1. **Always run through Ansible** - Ensures proper environment variables and logging
2. **Test in development first** - Verify script behavior before production
3. **Keep scripts idempotent** - Should be safe to re-run without side effects
4. **Document environment variables** - List all required and optional variables
5. **Use error handling** - Set `set -e` to exit on errors
6. **Log operations** - Echo what the script is doing for debugging
7. **Version control** - Keep scripts in Git with commit messages explaining changes

---

## Quick Reference

| Task | Command |
|------|---------|
| Run fix script via Ansible | `ansible-playbook -i inventory.ini provision.yml` |
| Manual execution | `KARAOKE_DB_PASSWORD="pass" bash fix-karaoke-user.sh` |
| Check if user exists | `docker exec postgres psql -U challenger_user -d postgres -c "\du karaoke_user"` |
| View database list | `docker exec postgres psql -U challenger_user -d postgres -c "\l"` |
| Test karaoke connection | `docker exec postgres psql -U karaoke_user -d karaoke_db -c "SELECT current_user;"` |
