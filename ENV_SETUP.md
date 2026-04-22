# Environment Variables Setup Guide

This project uses environment variables for secure and flexible configuration of database credentials and settings.

---

## 🔐 Quick Setup

### 1. Create Your .env File

The `.env` file is **already created** when you clone this repository (from `.env.example`).

If it doesn't exist, create it:
```bash
cp .env.example .env
```

### 2. Customize Credentials (Optional)

Edit `.env` to change default passwords:
```bash
nano .env
# or
vim .env
# or use your favorite editor
```

### 3. Start Containers

```bash
docker-compose up -d
```

Docker Compose will automatically load variables from `.env` file.

---

## 📋 Environment Variables Reference

### MariaDB 10
```bash
MARIADB_10_ROOT_PASSWORD=rootpass10      # Root password
MARIADB_10_DATABASE=testdb               # Database name
MARIADB_10_USER=testuser                 # Non-root user
MARIADB_10_PASSWORD=testpass             # Non-root password
MARIADB_10_PORT=3310                     # Host port
```

### MariaDB 11
```bash
MARIADB_11_ROOT_PASSWORD=rootpass11
MARIADB_11_DATABASE=testdb
MARIADB_11_USER=testuser
MARIADB_11_PASSWORD=testpass
MARIADB_11_PORT=3311
```

### MariaDB 12
```bash
MARIADB_12_ROOT_PASSWORD=rootpass12
MARIADB_12_DATABASE=testdb
MARIADB_12_USER=testuser
MARIADB_12_PASSWORD=testpass
MARIADB_12_PORT=3312
```

---

## 🔄 How It Works

### Docker Compose
The `docker-compose.yml` file uses variable substitution:

```yaml
environment:
  MYSQL_ROOT_PASSWORD: ${MARIADB_10_ROOT_PASSWORD:-rootpass10}
```

**Syntax:** `${VARIABLE:-default_value}`
- Uses `VARIABLE` from `.env` if it exists
- Falls back to `default_value` if not set

### Test Scripts
All test scripts automatically load `.env` variables:

```bash
# Loads environment variables
source "$(dirname "$0")/load-env.sh"

# Uses variables
docker exec -i mariadb-10 mysql -uroot -p$MARIADB_10_ROOT_PASSWORD
```

---

## 🛡️ Security Best Practices

### ✅ DO:
- ✅ Use `.env` for local development
- ✅ Keep `.env` out of version control (already in `.gitignore`)
- ✅ Use strong passwords for production
- ✅ Use different credentials per environment
- ✅ Share `.env.example` as a template

### ❌ DON'T:
- ❌ Commit `.env` to git (contains real passwords)
- ❌ Share `.env` file directly
- ❌ Use default passwords in production
- ❌ Hardcode passwords in scripts

---

## 🔧 Customization Examples

### Example 1: Strong Production Passwords

```bash
# .env
MARIADB_10_ROOT_PASSWORD=X9mK2#pL$vN8qR4@
MARIADB_11_ROOT_PASSWORD=T5wJ7&hD*sF3nP9^
MARIADB_12_ROOT_PASSWORD=B4cM6!gQ#yL2xH8%
```

### Example 2: Different Database Names

```bash
# .env
MARIADB_10_DATABASE=production_db
MARIADB_11_DATABASE=staging_db
MARIADB_12_DATABASE=testing_db
```

### Example 3: Custom Ports

```bash
# .env
MARIADB_10_PORT=13310
MARIADB_11_PORT=13311
MARIADB_12_PORT=13312
```

---

## 🚀 Using in Scripts

All test scripts automatically load environment variables:

```bash
# test-all-versions.sh
./test-all-versions.sh           # Automatically uses .env

# test-qpm-final.sh
./test-qpm-final.sh              # Automatically uses .env

# setup-newrelic.sh
./setup-newrelic.sh              # Automatically uses .env
```

### Manual Loading (Advanced)

If you need to load variables manually:

```bash
# Source the loader script
source ./load-env.sh

# Now variables are available
echo $MARIADB_10_ROOT_PASSWORD
```

---

## 📦 Distribution

### For GitHub Repository

1. ✅ **Commit**: `.env.example` (template with example values)
2. ❌ **Don't Commit**: `.env` (already in `.gitignore`)
3. ✅ **Document**: This guide (`ENV_SETUP.md`)

### For Team Members

Share the repository. They should:

```bash
# 1. Clone repository
git clone https://github.com/your-repo/mariadb-qpm-docker.git
cd mariadb-qpm-docker

# 2. .env is auto-created or copy from example
cp .env.example .env    # If needed

# 3. Customize if desired
nano .env

# 4. Start containers
docker-compose up -d
```

---

## 🔍 Troubleshooting

### Variables Not Loading

**Problem:** Scripts can't connect to database

**Solution:** Verify `.env` exists
```bash
ls -la .env
# Should show the file

# If missing:
cp .env.example .env
```

### Containers Not Starting

**Problem:** Docker Compose errors

**Solution:** Check `.env` syntax
```bash
# Ensure no spaces around =
CORRECT:  MARIADB_10_ROOT_PASSWORD=mypass
WRONG:    MARIADB_10_ROOT_PASSWORD = mypass
```

### Permission Denied

**Problem:** `load-env.sh` not executable

**Solution:**
```bash
chmod +x load-env.sh
```

### Old Passwords Cached

**Problem:** Changed `.env` but old passwords still used

**Solution:** Recreate containers
```bash
docker-compose down
docker volume rm mariadb-docker-setup_mariadb_10_data
docker-compose up -d
```

---

## 🎯 Default Values

If `.env` is missing or variables aren't set, these defaults are used:

| Variable | Default Value |
|----------|---------------|
| Root Passwords | `rootpass10`, `rootpass11`, `rootpass12` |
| Database Names | `testdb` (all versions) |
| Users | `testuser` (all versions) |
| User Passwords | `testpass` (all versions) |
| Ports | `3310`, `3311`, `3312` |

⚠️ **Note:** These are ONLY for testing. Change them for any non-local use!

---

## 📚 Related Documentation

- [README.md](README.md) - Main project documentation
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [.env.example](.env.example) - Environment template
- [.gitignore](.gitignore) - Git ignore rules

---

## ✅ Quick Checklist

Before pushing to GitHub:
- [ ] `.env.example` exists with example values
- [ ] `.env` is in `.gitignore`
- [ ] Real passwords are NOT in any committed files
- [ ] Documentation explains how to set up `.env`
- [ ] Test scripts work with environment variables

Before production deployment:
- [ ] Generated strong passwords
- [ ] Updated `.env` with production credentials
- [ ] Secured `.env` file permissions
- [ ] Documented password storage location (vault/secrets manager)
- [ ] Tested with new credentials

---

**Last Updated:** April 22, 2026  
**Status:** ✅ Environment variables fully integrated
