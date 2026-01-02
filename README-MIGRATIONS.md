# WWW Quest - Database Migration Playbooks

## Overview
This directory contains Ansible playbooks for managing database migrations for Challenger and Karaoke applications independently or together.

## Playbook Structure
```
ansible/
├── site.yml                      # Full deployment (infrastructure + all migrations)
├── provision.yml                 # Infrastructure setup only
├── migrate-challenger.yml        # Challenger DB migrations only
├── migrate-karaoke.yml          # Karaoke DB migrations only
├── migrate-all.yml              # Both migrations (no infrastructure)
└── inventory.ini                # Target hosts
```

## Architecture

**Database Setup:**
- Single PostgreSQL 15 instance
- Two isolated databases: `challenger_db` and `karaoke_db`
- Two separate users: `challenger_user` and `karaoke_user`
- Two Flyway containers: `flyway` and `flyway_karaoke`

**Migration Storage:**
- Challenger: `/opt/migrations/challenger/`
- Karaoke: `/opt/migrations/karaoke/`

## Usage Scenarios

### Scenario 1: Full Deployment (First Time Setup)
Use this when provisioning a new server with everything:

```bash
ansible-playbook -i inventory.ini site.yml
```

**What it does:**
1. Installs Docker and dependencies
2. Creates system user and directories
3. Deploys Docker Compose files and configurations
4. Starts PostgreSQL and PgAdmin containers
5. Creates karaoke_user if needed
6. Runs Challenger migrations
7. Runs Karaoke migrations

### Scenario 2: Run Only Challenger Migrations
Use this when deploying Challenger schema changes:

```bash
ansible-playbook -i inventory.ini migrate-challenger.yml
```

**What it does:**
1. Ensures `/opt/migrations/challenger/` exists
2. Uploads Challenger migration files
3. Checks PostgreSQL health
4. Runs Flyway migrations for `challenger_db`
5. Displays results and errors

**Use cases:**
- Deploying Challenger app updates with schema changes
- Testing Challenger migrations independently
- Rolling back only Challenger schema

### Scenario 3: Run Only Karaoke Migrations
Use this when deploying Karaoke schema changes:

```bash
ansible-playbook -i inventory.ini migrate-karaoke.yml
```

**What it does:**
1. Ensures `/opt/migrations/karaoke/` exists
2. Uploads Karaoke migration files
3. Checks PostgreSQL health
4. Runs Flyway migrations for `karaoke_db`
5. Displays results and errors

**Use cases:**
- Deploying Karaoke app updates with schema changes
- Testing Karaoke migrations independently
- Rolling back only Karaoke schema

### Scenario 4: Run All Migrations (No Provisioning)
Use this when infrastructure is already set up but you need to run all migrations:

```bash
ansible-playbook -i inventory.ini migrate-all.yml
```

**What it does:**
1. Runs migrate-challenger.yml
2. Runs migrate-karaoke.yml
3. Displays combined summary

**Use cases:**
- Deploying schema changes for both applications
- Re-running migrations after manual database cleanup
- Applying migrations after infrastructure changes

### Scenario 5: Infrastructure Only (No Migrations)
Use this when you only need to set up or update infrastructure:

```bash
ansible-playbook -i inventory.ini provision.yml
```

**What it does:**
- Everything in Scenario 1 except migrations
- Useful for infrastructure updates without schema changes

## Error Handling

All migration playbooks include:
- PostgreSQL health checks with 5 retries
- Graceful error handling (doesn't crash on failure)
- Detailed error output display
- Rollback instructions in error messages

**Example error output:**
```
TASK [Fail if Challenger migrations failed] ************************************
fatal: [db]: FAILED! => {
    "msg": "Challenger migrations failed with exit code 1.\n
            Review the output above for details.\n
            To rollback: docker compose --profile migrate run --rm flyway undo"
}
```

## Manual Migration Operations

### Check Migration Status
```bash
# SSH to server
ssh user@your-server

# Check Challenger migration status
cd /opt/wwwquest/postgres
docker compose --profile migrate run --rm flyway info

# Check Karaoke migration status
docker compose --profile migrate run --rm flyway_karaoke info
```

### Rollback Migrations
```bash
# Rollback Challenger migrations
docker compose --profile migrate run --rm flyway undo

# Rollback Karaoke migrations
docker compose --profile migrate run --rm flyway_karaoke undo
```

### Validate Migrations
```bash
# Validate Challenger migrations
docker compose --profile migrate run --rm flyway validate

# Validate Karaoke migrations
docker compose --profile migrate run --rm flyway_karaoke validate
```

### Repair Migration Checksums
```bash
# Repair Challenger schema history
docker compose --profile migrate run --rm flyway repair

# Repair Karaoke schema history
docker compose --profile migrate run --rm flyway_karaoke repair
```

## Migration File Management

### Adding New Migrations

**For Challenger:**
1. Create migration file: `ansible/files/challenger_migrations/V{VERSION}__{DESCRIPTION}.sql`
2. Run: `ansible-playbook -i inventory.ini migrate-challenger.yml`

**For Karaoke:**
1. Create migration file: `ansible/files/karaoke_migrations/V{VERSION}__{DESCRIPTION}.sql`
2. Run: `ansible-playbook -i inventory.ini migrate-karaoke.yml`

**Naming convention:**
- `V1__Initial_Schema.sql`
- `V2__Add_User_Preferences.sql`
- `V3__Create_Quiz_Tables.sql`

### Migration File Location
```
ansible/
└── files/
    ├── challenger_migrations/
    │   ├── V1__Create_Enums.sql
    │   ├── V2__Create_Core_Tables.sql
    │   └── ...
    └── karaoke_migrations/
        ├── V1__Initial_Schema.sql
        └── ...
```

## Troubleshooting

### Problem: PostgreSQL not healthy
**Symptoms:** Health check fails after 5 retries
**Solution:**
```bash
ssh user@your-server
cd /opt/wwwquest/postgres
docker compose logs postgres
docker compose restart postgres
```

### Problem: Migration checksum mismatch
**Symptoms:** `ERROR: Validate failed: Migration checksum mismatch`
**Solution:**
```bash
# Option 1: Repair checksums (if file was modified intentionally)
docker compose --profile migrate run --rm flyway repair

# Option 2: Undo and reapply
docker compose --profile migrate run --rm flyway undo
ansible-playbook -i inventory.ini migrate-challenger.yml
```

### Problem: Karaoke user doesn't exist
**Symptoms:** `FATAL: role "karaoke_user" does not exist`
**Solution:**
```bash
# Re-run provisioning (includes karaoke user fix)
ansible-playbook -i inventory.ini provision.yml
```

### Problem: Migration already applied
**Symptoms:** `ERROR: Found non-ignored repeatable migration`
**Solution:**
This is normal. Flyway skips already-applied migrations automatically.

## Best Practices

1. **Test in Staging First:** Always run migrations in staging environment before production
2. **Independent Deployments:** Deploy Challenger and Karaoke migrations separately unless coordinated release
3. **Backup Before Migration:** Take database backup before running migrations
4. **Monitor Logs:** Check migration output for warnings even if successful
5. **Version Control:** Keep migration files in version control
6. **Never Modify Applied Migrations:** Create new migrations for schema changes

## Configuration Variables

Located in `ansible/group_vars/db.yml`:
- `system_user`: User for running services (default: `wwwquest`)
- `project_dir`: Base directory (default: `/opt/wwwquest`)
- `migrations_root`: Migration storage (default: `/opt/migrations`)
- `challenger_db_password`: Challenger database password
- `karaoke_db_password`: Karaoke database password

## Support

For issues or questions:
1. Check playbook output for detailed error messages
2. Review PostgreSQL logs: `docker compose logs postgres`
3. Check Flyway logs in migration output
4. Consult Flyway documentation: https://documentation.red-gate.com/fd

## Quick Reference

| Task | Command |
|------|---------|
| Full deployment | `ansible-playbook -i inventory.ini site.yml` |
| Provision only | `ansible-playbook -i inventory.ini provision.yml` |
| Challenger migrations | `ansible-playbook -i inventory.ini migrate-challenger.yml` |
| Karaoke migrations | `ansible-playbook -i inventory.ini migrate-karaoke.yml` |
| Both migrations | `ansible-playbook -i inventory.ini migrate-all.yml` |
| Check migration status | `docker compose --profile migrate run --rm flyway info` |
| Rollback migration | `docker compose --profile migrate run --rm flyway undo` |
