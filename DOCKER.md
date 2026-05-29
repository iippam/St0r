# Docker Deployment Guide for St0r

This guide walks you through deploying St0r using Docker and Docker Compose on your Debian server with UrBackup.

## Prerequisites

- Docker (20.10+)
- Docker Compose (2.0+)
- Debian 13 server with UrBackup Server 2.5.x or later installed
- UrBackup database located at `/var/urbackup/backup_server.db`

### Install Docker on Debian 13

```bash
# Update package manager
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker and Docker Compose
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add your user to docker group (optional, requires logout/login)
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker compose version
```

## Quick Start

### 1. Clone or Navigate to Repository

```bash
cd /path/to/St0r
```

### 2. Configure Environment Variables

```bash
# Copy example environment file
cp .env.example .env

# Edit with your UrBackup credentials
nano .env
```

**Important environment variables:**

```bash
# Database credentials (for St0r app database)
DB_ROOT_PASSWORD=your-secure-root-password
DB_USER=urbackup
DB_PASSWORD=your-secure-db-password

# JWT and encryption secrets (generate with: openssl rand -hex 32)
JWT_SECRET=your-32-character-secret
APP_SECRET_KEY=your-32-character-secret

# UrBackup connection
URBACKUP_DB_PATH=/var/urbackup/backup_server.db
URBACKUP_API_URL=http://localhost:55414/x
URBACKUP_USERNAME=admin
URBACKUP_PASSWORD=your-urbackup-password
```

### 3. Make Script Executable

```bash
chmod +x scripts/docker-run.sh
```

### 4. Build and Start Containers

```bash
./scripts/docker-run.sh
```

Or manually:

```bash
# Build images
docker-compose build

# Start services
docker-compose up -d

# Check status
docker-compose ps
```

### 5. Access the Application

- **Web Interface**: http://your-server-ip
- **Backend API**: http://your-server-ip:3000
- **Database**: localhost:3306

**Default Credentials:**
- Username: `admin`
- Password: `admin123`

⚠️ **Change the default password immediately** after first login!

## Service Details

### Container Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Docker Compose Network                      │
│                  (st0r-network)                          │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │ Frontend │  │ Backend  │  │   MariaDB Database   │  │
│  │(Nginx)   │─→│(Express) │←→│ (urbackup_gui db)    │  │
│  │  :80     │  │  :3000   │  │  :3306 (internal)    │  │
│  └──────────┘  └──────────┘  └──────────────────────┘  │
│                      ↓                                    │
│              UR Backup Server                            │
│         (on host: /var/urbackup/...)                    │
│         (read-only mount)                                │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### Services

#### Frontend (`st0r-frontend`)
- **Image**: Custom built from `frontend/Dockerfile`
- **Port**: 80 (HTTP), 443 (HTTPS if certificates provided)
- **Technology**: Node.js 20 (build) + Nginx (runtime)
- **Features**:
  - React SPA with Vite
  - Reverse proxy to backend API
  - Static file caching
  - Gzip compression

#### Backend (`st0r-backend`)
- **Image**: Custom built from `backend/Dockerfile`
- **Port**: 3000 (internal only, exposed through Nginx)
- **Technology**: Node.js 20 with Express
- **Connections**:
  - MariaDB database on `db:3306`
  - UrBackup database (read-only) at `/urbackup/backup_server.db`
  - UrBackup API at configured `URBACKUP_API_URL`
- **Health Check**: HTTP endpoint every 30 seconds

#### Database (`st0r-db`)
- **Image**: `mariadb:11.3-alpine`
- **Port**: 3306 (exposed for debugging, internal default)
- **Volume**: `db_data` (persistent storage)
- **Initialization**: Auto-runs SQL files from `database/init/` and `database/migrations/`
- **Health Check**: Native MariaDB health check

## Common Operations

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f db

# Last 50 lines
docker-compose logs --tail 50
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart backend
```

### Stop Services

```bash
# Stop (can restart later)
docker-compose stop

# Stop specific service
docker-compose stop backend
```

### Completely Remove Everything

```bash
# Stop and remove containers, networks
docker-compose down

# Also remove volumes (DATABASE WILL BE DELETED!)
docker-compose down -v
```

### Execute Commands in Running Containers

```bash
# Access backend shell
docker-compose exec backend sh

# Access database CLI
docker-compose exec db mysql -u urbackup -p urbackup_gui

# View backend process
docker-compose exec backend ps aux
```

### Rebuild Images

```bash
# Rebuild all images
docker-compose build --no-cache

# Rebuild specific service
docker-compose build --no-cache backend

# Rebuild and restart
docker-compose up -d --build
```

## Troubleshooting

### Container won't start

```bash
# Check logs
docker-compose logs backend

# Check if ports are already in use
sudo lsof -i :80
sudo lsof -i :3000
sudo lsof -i :3306

# Kill process on port (e.g., port 80)
sudo fuser -k 80/tcp
```

### Database connection error

```bash
# Wait for database to be ready
docker-compose logs db

# Test database connection
docker-compose exec backend mysql -h db -u urbackup -p urbackup_gui -e "SELECT 1;"
```

### UrBackup database not found

```bash
# Verify UrBackup database exists on host
ls -la /var/urbackup/backup_server.db

# Check if container can read it
docker-compose exec backend ls -la /urbackup/backup_server.db

# Fix permissions if needed
sudo chmod 644 /var/urbackup/backup_server.db
sudo chown root:root /var/urbackup/backup_server.db
```

### Frontend not connecting to backend

```bash
# Check Nginx config
docker-compose exec frontend nginx -t

# Verify backend is running
docker-compose ps backend

# Test backend from frontend
docker-compose exec frontend curl http://backend:3000
```

### Permission issues with volumes

```bash
# Fix database volume permissions
sudo chown -R 999:999 db_data/

# Check volume location
docker volume inspect st0r_db_data
```

## HTTPS Configuration

### Using Let's Encrypt with Certbot

```bash
# Install Certbot
sudo apt-get install -y certbot python3-certbot-dns-cloudflare

# Obtain certificates (example with Cloudflare)
sudo certbot certonly --dns-cloudflare -d yourdomain.com -d www.yourdomain.com

# Copy certificates to certs directory
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ./certs/
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ./certs/
sudo chown $USER:$USER ./certs/*
```

Then update `docker-compose.yml` to mount and use the certificates.

## Performance Tuning

### Database Optimization

```bash
# Access MariaDB CLI
docker-compose exec db mysql -u root -p

# Check slow queries
SHOW VARIABLES LIKE 'slow_query%';
```

### Resource Limits

Add to `docker-compose.yml` service definitions:

```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

## Backup and Recovery

### Backup Database

```bash
# Dump database
docker-compose exec db mysqldump -u urbackup -p urbackup_gui > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup volumes
docker run --rm -v st0r_db_data:/data -v $(pwd):/backup alpine tar czf /backup/db_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C / data
```

### Restore Database

```bash
# Restore from SQL dump
docker-compose exec -T db mysql -u urbackup -p urbackup_gui < backup_20250529_120000.sql

# Restore from volume backup
docker run --rm -v st0r_db_data:/data -v $(pwd):/backup alpine tar xzf /backup/db_backup_20250529_120000.tar.gz -C /
```

## Monitoring

### Container Stats

```bash
# Real-time stats
docker stats

# Specific container
docker stats st0r-backend
```

### System Resource Usage

```bash
# Check disk usage
docker system df

# Prune unused images/containers
docker system prune -a
```

## Production Checklist

- [ ] Change all default passwords in `.env`
- [ ] Generate new JWT_SECRET and APP_SECRET_KEY with `openssl rand -hex 32`
- [ ] Set up HTTPS with valid certificates
- [ ] Configure automated backups
- [ ] Set up log rotation
- [ ] Configure monitoring/alerting
- [ ] Test disaster recovery procedures
- [ ] Document any custom configurations
- [ ] Set resource limits on containers
- [ ] Enable firewall rules (only open necessary ports)

## Support

For issues, please check:
1. Container logs: `docker-compose logs`
2. Service health: `docker-compose ps`
3. UrBackup integration: Verify credentials and database path
4. GitHub Issues: https://github.com/iippam/St0r/issues

## Next Steps

After successful deployment:
1. Log in with default credentials
2. Change your password
3. Configure UrBackup integration settings
4. Set up backup clients
5. Enable 2FA for security
6. Configure replication targets (if needed)
