# DevOps Project - Coffee Delivery Service

A fully automated DevOps pipeline with CI/CD, high availability, and disaster recovery.

---

## 📁 Project Structure

```
devops-project/
├── .github/workflows/          # GitHub Actions CI/CD
│   ├── deploy.yml              # Auto-deploy to VCL2 on push to main
│   ├── pr-test.yml             # Run tests on pull requests
│   └── sync-dev.yml            # Auto-sync dev branch after PR merge
│
├── ansible/                    # Infrastructure automation
│   ├── inventory.yml           # Server IPs and SSH config
│   ├── site.yml                # Master playbook (runs all)
│   ├── 0-setup-ssh-keys.yml    # SSH key distribution
│   ├── deploy.yml              # Deploy app to VCL2
│   ├── setup-vcl1-loadbalancer.yml  # Nginx load balancer
│   ├── setup-vcl3-monitor.yml  # Health monitoring + failover
│   └── setup-replication.yml   # Database replication cron
│
├── coffee_project/             # Node.js application
│   ├── app.js                  # Express server + API routes
│   ├── db.js                   # PostgreSQL connection
│   ├── migrate.js              # Database migrations
│   ├── data.js                 # Seed data
│   ├── Dockerfile              # Container definition
│   ├── docker-compose.yml      # App + DB containers
│   ├── test/                   # Unit tests (Jest)
│   └── public/                 # Frontend (HTML/JS)
│
├── scripts/                    # Utility scripts
│   ├── replicate-db.sh         # DB backup VCL2 → VCL3
│   ├── reverse-replicate-db.sh # DB sync VCL3 → VCL2 (failback)
│   ├── monitor-vcl2-health.sh  # Health check + auto-failover
│   ├── manual-failover-to-vcl3.sh
│   ├── failback-to-vcl2.sh
│   └── systemd/                # Systemd service files
│
└── load_balancer/              # Nginx config for VCL1
```

---

## 🖥️ Infrastructure

| Server | IP | Role |
|--------|-----|------|
| VCL1 | 152.7.178.184 | Load Balancer (Nginx) |
| VCL2 | 152.7.178.106 | Primary App Server |
| VCL3 | 152.7.178.91 | Cold Standby + Failover |

**High Availability Features:**
- ✅ Automatic deployment to VCL2 on merge to `main` branch
- ✅ Database replication from VCL2 to VCL3 every 2 minutes
- ✅ Auto-failover when VCL2 goes down (within 90 seconds)
- ✅ Reverse replication on failback (preserve data)
- ✅ Auto-sync `dev` branch after PR merge to `main`
- ✅ Linting and testing in CI/CD pipeline

---

## 🔄 CI/CD Workflows

Location: `.github/workflows/`

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `deploy.yml` | Push to `main` | Run tests → Deploy to VCL2 |
| `pr-test.yml` | Pull request | Run linting + unit tests |
| `sync-dev.yml` | PR merged to `main` | Auto-merge main back to dev |

**Quality Gate:** Tests must pass before deploy happens.

---

## 🛠️ Ansible Playbooks

Location: `ansible/`

| Playbook | Purpose |
|----------|---------|
| `site.yml` | Master playbook - runs everything |
| `0-setup-ssh-keys.yml` | Distribute SSH keys to all servers |
| `deploy.yml` | Deploy app to VCL2 |
| `setup-vcl1-loadbalancer.yml` | Configure Nginx on VCL1 |
| `setup-vcl3-monitor.yml` | Install health monitor + failover service |
| `setup-replication.yml` | Set up DB replication cron (every 2 min) |

**Run all setup:**
```bash
cd ansible
ansible-playbook -i inventory.yml site.yml
```

---

## 🚀 Quick Start

### Run Locally with Docker
```bash
cd coffee_project
docker compose up -d
```

This starts:
- Coffee app on http://localhost:3000
- PostgreSQL database on port 5432

### Test the App
```bash
# Get available coffees
curl http://localhost:3000/coffees

# Place an order
curl -X POST http://localhost:3000/order \
  -H "Content-Type: application/json" \
  -d '{"coffeeId": 1, "quantity": 2}'

# View all orders
curl http://localhost:3000/orders
```

### Stop Containers
```bash
docker compose down
```

---

## 🔁 High Availability

### Database Replication (VCL2 → VCL3)
- **Frequency:** Every 2 minutes via cron
- **Method:** `pg_dump` → SCP to VCL3 → Store as backup
- **Script:** Deployed by `ansible/setup-replication.yml`

### Health Monitoring (on VCL3)
- **Checks:** `curl http://VCL2:3000/coffees` every 30 seconds
- **Failover:** After 3 failed checks, VCL3 activates automatically
- **Script:** Deployed by `ansible/setup-vcl3-monitor.yml`

### Failover Process
1. VCL3 detects VCL2 is down (3 failed health checks)
2. Starts database container
3. Restores from latest backup
4. Starts app container
5. VCL3 now serves traffic with production data

### Failback Process
1. VCL3 detects VCL2 is back online
2. Syncs database back to VCL2 (preserves new data)
3. Stops VCL3 containers
4. VCL2 resumes as primary

### Manual Failover (if needed)
```bash
# On VCL3
cd ~/devops-project/coffee_project
docker compose up -d
curl http://localhost:3000/coffees
```

---

## 🗄️ Database (PostgreSQL)

The app uses PostgreSQL. Connection is read from `DATABASE_URL` env variable.

**Default:** `postgresql://postgres:postgres@localhost:5432/coffee_dev`

### Run Without Docker
```bash
# Start postgres container
docker run --name coffee-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=coffee_dev -p 5432:5432 -d postgres:15

# Install deps and migrate
cd coffee_project
npm install
npm run migrate
npm start
```

---

## 🚢 Automated Deployment

GitHub Actions automatically deploys to VCL2 when code is merged to `main`.

### How It Works
1. PR merged to `main` → triggers workflow
2. Tests run first (quality gate)
3. SSH into VCL2 → pull latest code
4. Rebuild Docker containers
5. App live at http://152.7.178.106:3000

### GitHub Secrets Required
- `VCL2_SSH_PRIVATE_KEY` - SSH key for VCL2 access
- `VCL2_SSH_KNOWN_HOSTS` - (optional) Host key

### Manual Deploy (if needed)
```bash
ssh sraval@152.7.178.106
cd ~/devops-project/coffee_project
git pull origin main
docker compose down
docker compose up -d --build
```

---

## 📝 Documentation

| Doc | Location |
|-----|----------|
| Replication Guide | `scripts/REPLICATION_USAGE.md` |
| Docker Setup | `coffee_project/DOCKER.md` |
| Ansible Guide | `ansible/README.md` |

---

## 👥 Team

- **Vatsalkumar Patel** - CI/CD, GitHub Actions, rollback, monitoring
- **Smit Sunilkumar Raval** - Ansible, infrastructure, replication, failover