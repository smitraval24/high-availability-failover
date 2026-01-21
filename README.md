# High-Availability Failover System

A production-ready CI/CD pipeline with high availability and automatic failover capabilities. Deploy to any infrastructure - AWS, Azure, local servers, or any cloud provider.

## Features

- **Automatic Failover**: Primary server goes down? Backup takes over automatically
- **Database Replication**: Continuous sync between primary and backup servers
- **Safe Deployments**: Automatic backup before deploy, rollback on failure
- **CI/CD Pipeline**: Automated testing and deployment via GitHub Actions
- **Cloud Agnostic**: Works on AWS, Azure, GCP, VPS, or bare metal servers

## Architecture

```
                    Users
                      │
              ┌───────┴───────┐
              │               │
         [Load Balancer]  [GitHub Actions]
              │            CI/CD Pipeline
              │
       ┌──────┴──────┐
       │             │
   [PRIMARY]    [BACKUP]
   App + DB     Standby
       │             │
       └─────────────┘
         DB Replication
```

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/smitraval24/high-availability-failover.git
cd high-availability-failover

# Copy the example configuration
cp config/config.env.example config/config.env

# Edit with your server details
nano config/config.env
```

### 2. Configure Your Servers

Edit `config/config.env` with your infrastructure:

```bash
# Required: Primary server (where app runs normally)
PRIMARY_HOST=your-primary-server-ip
PRIMARY_USER=your-ssh-username

# Required: Backup server (takes over if primary fails)
BACKUP_HOST=your-backup-server-ip
BACKUP_USER=your-ssh-username

# Optional: Load balancer
LB_HOST=your-loadbalancer-ip
LB_USER=your-ssh-username
```

### 3. Bootstrap Server Connectivity

Run from your local machine to set up SSH keys between servers:

```bash
cd scripts
bash local-bootstrap.sh
```

### 4. Run Ansible Setup

SSH into your primary server and run the setup:

```bash
ssh your-user@your-primary-ip
cd high-availability-failover/ansible
bash SETUP.sh
```

### 5. Configure GitHub Actions

In your GitHub repository settings, add:

**Secrets** (Settings → Secrets and variables → Actions → Secrets):
- `PRIMARY_SSH_PRIVATE_KEY`: SSH private key for primary server
- `BACKUP_SSH_PRIVATE_KEY`: SSH private key for backup server

**Variables** (Settings → Secrets and variables → Actions → Variables):
- `PRIMARY_HOST`: IP/hostname of primary server
- `PRIMARY_USER`: SSH username for primary server
- `BACKUP_HOST`: IP/hostname of backup server
- `BACKUP_USER`: SSH username for backup server

**Optional Variables:**
- `RUNNER`: Set to `self-hosted, linux, x64` for self-hosted runner (defaults to `ubuntu-latest`)
- `PROJECT_DIR`: Project directory name (default: `high-availability-failover`)
- `APP_PORT`: Application port (default: `3000`)

## Directory Structure

```
high-availability-failover/
├── config/
│   ├── config.env.example    # Template - copy to config.env
│   └── defaults.env          # Default values
├── coffee_project/           # Sample Node.js application
│   ├── app.js               # Express API
│   ├── docker-compose.yml   # Container orchestration
│   └── test/                # Test suite
├── ansible/                  # Infrastructure automation
│   ├── inventory.yml        # Server definitions
│   ├── site.yml             # Main playbook
│   └── *.yml                # Individual playbooks
├── scripts/                  # Operational scripts
│   ├── local-bootstrap.sh   # Initial SSH setup
│   ├── monitor-primary-health.sh  # Failover monitor
│   ├── replicate-db.sh      # Database replication
│   ├── backup-container.sh  # Pre-deploy backup
│   └── rollback-container.sh # Rollback on failure
├── load_balancer/           # Nginx configuration
└── .github/workflows/       # CI/CD pipelines
    ├── deploy.yml           # Production deployment
    ├── pr-test.yml          # PR testing
    └── sync-dev.yml         # Branch sync
```

## How It Works

### CI/CD Pipeline

1. **Pull Request**: Runs linting and tests automatically
2. **Merge to main**: Triggers deployment workflow
3. **Deployment**:
   - Creates backup of current container
   - Pulls latest code
   - Builds and starts new containers
   - Runs health checks
   - Rolls back automatically if health checks fail
4. **Post-deploy**: Syncs code to backup server

### Failover System

1. **Monitor** (runs on backup server):
   - Pings primary server every 30 seconds
   - After 3 consecutive failures, triggers failover

2. **Failover**:
   - Starts application on backup server
   - Restores database from latest replication
   - Traffic automatically routes to backup

3. **Recovery**:
   - When primary recovers, syncs database back
   - Backup returns to standby mode

### Database Replication

- Runs every 30 minutes (configurable)
- `pg_dump` on primary → SCP → restore on backup
- Ensures minimal data loss during failover

## Configuration Reference

### config/config.env

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PRIMARY_HOST` | Yes | - | Primary server IP/hostname |
| `PRIMARY_USER` | Yes | - | SSH username for primary |
| `BACKUP_HOST` | Yes | - | Backup server IP/hostname |
| `BACKUP_USER` | Yes | - | SSH username for backup |
| `LB_HOST` | No | - | Load balancer IP (optional) |
| `APP_NAME` | No | `coffee` | Application name |
| `APP_PORT` | No | `3000` | Application port |
| `DB_NAME` | No | `coffee_dev` | Database name |
| `HEALTH_CHECK_INTERVAL` | No | `30` | Seconds between health checks |
| `FAIL_THRESHOLD` | No | `3` | Failures before failover |
| `DOMAIN_NAME` | No | - | Domain name (optional) |

### GitHub Actions Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PRIMARY_HOST` | Yes | - | Primary server IP |
| `PRIMARY_USER` | Yes | - | Primary SSH user |
| `BACKUP_HOST` | Yes | - | Backup server IP |
| `BACKUP_USER` | Yes | - | Backup SSH user |
| `RUNNER` | No | `ubuntu-latest` | Runner type |
| `PROJECT_DIR` | No | `high-availability-failover` | Project directory |
| `APP_PORT` | No | `3000` | Application port |

## Deployment Options

### Option 1: Two Servers (Recommended Minimum)

- Primary server: Runs application + database
- Backup server: Standby for failover

### Option 2: Three Servers (Full Setup)

- Load Balancer: Nginx reverse proxy
- Primary server: Main application
- Backup server: Failover standby

### Option 3: Cloud Providers

Works with any cloud that supports:
- Linux VMs with SSH access
- Docker and Docker Compose
- Outbound internet (for GitHub Actions)

**Tested on:**
- AWS EC2
- Azure VMs
- Google Cloud Compute
- DigitalOcean Droplets
- Linode
- VCL (Virtual Computing Lab)

## Customizing for Your Application

1. Replace `coffee_project/` with your application
2. Update `docker-compose.yml` for your stack
3. Modify health check endpoint in `config/config.env`:
   ```bash
   HEALTH_ENDPOINT=/your-health-endpoint
   ```
4. Update container names if different:
   ```bash
   APP_CONTAINER=your_app
   DB_CONTAINER=your_db
   ```

## Troubleshooting

### Deployment Fails

1. Check GitHub Actions logs
2. Verify SSH keys are correctly configured
3. Ensure servers are reachable from GitHub runner

### Failover Not Working

1. Check monitor logs: `journalctl -u monitor-primary -f`
2. Verify backup server can reach primary
3. Check database replication status

### Health Checks Failing

1. Verify application is running: `docker-compose ps`
2. Test endpoint manually: `curl http://localhost:3000/coffees`
3. Check application logs: `docker-compose logs app`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `cd coffee_project && npm test`
5. Submit a pull request

## License

ISC License

## Credits

Originally developed as a DevOps course project demonstrating CI/CD, high availability, and infrastructure automation.
