# DevOps Project

This repository contains the main DevOps project with a coffee delivery service.

## Infrastructure

**VCL Machines:**
- **VCL 1**: 152.7.178.184 (Routing and DNS)
- **VCL 2**: 152.7.178.106 (Primary server with auto-deployment + Cloudflare Tunnel)
- **VCL 3**: 152.7.178.91 (Cold standby server with DB replication)

**Public Access:**
- **Cloudflare Tunnel**: Secure public access via `https://coffee-vcl2-*.trycloudflare.com`
  - No domain required
  - Free HTTPS/SSL
  - DDoS protection
  - Zero-trust security (no exposed IP)

**High Availability Features:**
- ✅ Automatic deployment to VCL2 on merge to `main` branch
- ✅ **Automatic rollback** on deployment failure (restores previous version)
- ✅ Database replication from VCL2 to VCL3 every 2 minutes
- ✅ Auto-sync `dev` branch after PR merge to `main`
- ✅ Linting and testing in CI/CD pipeline
- ✅ Cloudflare Tunnel for secure public access (no domain needed)

## Quick Start with Docker

Run the coffee project with PostgreSQL database using Docker:

```bash
cd coffee_project
docker-compose up -d
```

This starts:
- Coffee app on http://localhost:3000
- PostgreSQL database on port 5432

### Test the app
```bash
# Get available coffees
curl http://localhost:3000/coffees

# Place an order
curl -X POST http://localhost:3000/order \
  -H "Content-Type: application/json" \
  -d '{"coffeeId": 1, "quantity": 2}'
```

### Stop containers
```bash
docker-compose down
```

## Public Access via Cloudflare Tunnel

Access your coffee app from anywhere using Cloudflare Tunnel (no domain required):

### One-Time Setup on VCL2

```bash
cd ~/devops-project
chmod +x scripts/setup-cloudflare-tunnel.sh
./scripts/setup-cloudflare-tunnel.sh
```

This will:
- Install `cloudflared`
- Create a persistent tunnel
- Set up auto-start on boot
- Give you a public URL like `https://coffee-vcl2-abc123.trycloudflare.com`

### Get Your Public URL

```bash
# Quick way
chmod +x scripts/get-tunnel-url.sh
./scripts/get-tunnel-url.sh

# Or check logs
sudo journalctl -u cloudflared | grep trycloudflare.com
```

### Test Public Access

```bash
# Replace with your actual URL
curl https://your-tunnel-url.trycloudflare.com/coffees
```

**Full Documentation**: See [CLOUDFLARE_TUNNEL_SETUP.md](CLOUDFLARE_TUNNEL_SETUP.md)

## High Availability Setup

### Database Replication (VCL2 → VCL3)

Automatic database replication runs every 2 minutes to keep VCL3 in sync with VCL2.

**Setup on VCL2:**
```bash
# Quick setup
cd ~/devops-project
chmod +x scripts/setup-replication.sh
./scripts/setup-replication.sh

# Follow the prompts to complete setup
```

**Detailed Documentation:**
- [Replication Setup Guide](scripts/REPLICATION_SETUP.md)
- [Systemd Timer Setup](scripts/systemd/SYSTEMD_SETUP.md)

**Monitor Replication:**
```bash
# View replication logs
tail -f /var/log/coffee-replication/replicate.log

# Check replication status (if using systemd)
systemctl status coffee-replication.timer
```

### Failover to VCL3

If VCL2 fails, activate VCL3:
```bash
# On VCL3
cd ~/devops-project/coffee_project
docker-compose up -d

# Verify
curl http://localhost:3000/coffees
```

Then update DNS/routing on VCL1 to point traffic to VCL3.

## Database setup (PostgreSQL)

This project uses PostgreSQL for the `coffee_project` service. The app reads the connection from the `DATABASE_URL` environment variable. If `DATABASE_URL` is not set, the project defaults to:

```
postgresql://postgres:postgres@localhost:5432/coffee_dev
```

Quick start (Docker)

1. Start a local Postgres container:

```bash
docker run --name coffee-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=coffee_dev -p 5432:5432 -d postgres:15
```

2. Install dependencies and run the migration to create tables and seed the coffee catalogue:

```bash
cd coffee_project
npm install
npm run migrate
```

3. Start the service:

```bash
npm start
# or run in a detached screen session:
screen -S coffee -dm sh -c 'npm start'
```

Using an existing / hosted database

If you have a hosted Postgres instance, set `DATABASE_URL` before running the migrate script or starting the server:

```bash
export DATABASE_URL='postgresql://USER:PASSWORD@HOST:PORT/DBNAME'
npm run migrate
npm start
```

CI (GitHub Actions) notes

If you run tests or migrations in GitHub Actions, start a Postgres service in the job and set `DATABASE_URL` to point to the service. Example snippet for a job in `.github/workflows/*.yml`:

```yaml
services:
	postgres:
		image: postgres:15
		env:
			POSTGRES_DB: coffee_test
			POSTGRES_USER: postgres
			POSTGRES_PASSWORD: postgres
		ports: ['5432:5432']
		options: >-
			--health-cmd pg_isready
			--health-interval 10s
			--health-timeout 5s
			--health-retries 5

env:
	DATABASE_URL: postgres://postgres:postgres@localhost:5432/coffee_test
```

Cleanup

To stop and remove the local docker container:

```bash
docker stop coffee-pg && docker rm coffee-pg
```

Questions or different DB?

If you'd prefer a different database (MySQL, MongoDB, etc.) I can adapt the code and migration script — tell me which one and I'll implement the change.

## Automated Deployment

The project uses GitHub Actions to automatically deploy to VCL 2 when code is merged to `main`.

### How it works

1. When a PR is merged to `main`, the deployment workflow triggers
2. The workflow (running on the self-hosted runner on VCL 1) SSHs into VCL 2
3. **Creates a backup** of the current running container
4. Pulls the latest code from the `main` branch
5. Stops old Docker containers
6. Rebuilds and starts new containers with the updated code
7. **Runs health checks** (HTTP + Database)
8. **If health checks pass:** Cleans up backup and syncs to VCL3 ✓
9. **If health checks fail:** Automatically rolls back to previous version ✗

The app is accessible at **http://152.7.178.106:3000**

### Automatic Rollback

If a deployment fails health checks, the system **automatically restores** the previous working version:

- ✅ Zero manual intervention required
- ✅ Application stays online (no downtime)
- ✅ Previous container is restored within seconds
- ✅ Database remains unchanged (app-only rollback)

**Health Check Criteria:**
- HTTP endpoint responds: `GET /coffees` returns 200 OK
- Database is ready: `pg_isready` succeeds
- All checks must pass within 60 seconds

**Full Documentation:** See [ROLLBACK_GUIDE.md](ROLLBACK_GUIDE.md) for detailed information

### Prerequisites for deployment

**On VCL 2 (152.7.178.106):**
- Docker and Docker Compose installed
- Project cloned at `~/devops-project`
- SSH access configured for GitHub Actions

**GitHub Repository Secrets (required):**
- `VCL2_SSH_PRIVATE_KEY` - SSH private key for accessing VCL 2
- `VCL2_SSH_KNOWN_HOSTS` - (optional) Host key for VCL 2

### Setting up SSH for GitHub Actions

1. Generate a dedicated SSH key pair:
```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy_key
```

2. Copy the public key to VCL 2:
```bash
ssh-copy-id -i ~/.ssh/github_actions_deploy_key.pub vpatel29@152.7.178.106
```

3. Add the private key to GitHub Secrets:
```bash
# Copy the private key
cat ~/.ssh/github_actions_deploy_key

# Go to: Repository Settings → Secrets and variables → Actions
# Create secret: VCL2_SSH_PRIVATE_KEY
# Paste the entire private key content (including BEGIN/END lines)
```

4. (Optional) Add known hosts:
```bash
ssh-keyscan -H 152.7.178.106

# Add as secret: VCL2_SSH_KNOWN_HOSTS
```

### Manual deployment on VCL 2

If you need to deploy manually:

```bash
ssh vpatel29@152.7.178.106
cd ~/devops-project
git pull origin main
cd coffee_project
docker-compose down
docker-compose up -d --build
```

### Manual rollback on VCL 2

If you need to manually rollback to the previous version:

```bash
ssh vpatel29@152.7.178.106
cd ~/devops-project
./scripts/rollback-container.sh
```

**Note:** Manual rollback only works if a backup exists. Backups are automatically created before each deployment and cleaned up after successful deployments.

### Accessing the deployed app

Once deployed, the coffee delivery service is accessible at:
- **http://152.7.178.106:3000**

Test endpoints:
```bash
# Get available coffees
curl http://152.7.178.106:3000/coffees

# Place an order
curl -X POST http://152.7.178.106:3000/order \
  -H "Content-Type: application/json" \
  -d '{"coffeeId": 1, "quantity": 2}'

# View all orders
curl http://152.7.178.106:3000/orders
```