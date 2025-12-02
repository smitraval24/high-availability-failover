# CSC 519 - DevOps Project

**Coffee Project** with automated CI/CD pipeline, high availability, and disaster recovery.

---

## Infrastructure

| Server | IP | Role |
|--------|-----|------|
| **VCL1** | 152.7.178.184 | nginx Load Balancer and GitHub Actions Runner (Self-hosted) |
| **VCL2** | 152.7.178.106 | Primary Application Server |
| **VCL3** | 152.7.178.91 | Cold Standby (Failover) |

---

## Features Implemented

### 1. CI/CD Pipeline

| Feature | Implementation | Trigger |
|---------|---------------|---------|
| **Linting** | ESLint via `pr-test.yml` | On Pull Request |
| **Unit Tests** | Jest via `pr-test.yml` | On Pull Request |
| **Auto Deploy** | `deploy.yml` → SSH to VCL2 | On push to `main` |
| **Branch Sync** | `sync-dev.yml` back-merges main to dev | After PR merge |

**Workflow Files:** `.github/workflows/`

---

### 2. Backup & Rollback

| Feature | Implementation |
|---------|---------------|
| **Pre-deploy Backup** | `deploy.yml` creates timestamped backup before each deploy |
| **Auto Rollback** | `deploy.yml` restores previous version if deployment fails |
| **Manual Rollback** | Can restore any backup from `~/backups/` on VCL2 |


---

### 3. Database Replication

| Feature | Implementation |
|---------|---------------|
| **VCL2 → VCL3 Sync** | `coffee-replication.timer` runs every 30 seconds |
| **Method** | `pg_dump` on VCL2 → SCP to VCL3 → Store in `/tmp/db-backup/` |
| **Script** | `scripts/replicate-db.sh` |

**Systemd Service:** `/etc/systemd/system/coffee-replication.service` on VCL2

---

### 4. Failover (High Availability)

| Feature | Implementation |
|---------|---------------|
| **Health Monitor** | `monitor-vcl2-health.sh` on VCL3 checks VCL2 every 10 seconds |
| **Auto Failover** | After 3 failed checks (~30 sec), VCL3 activates automatically |
| **Auto Failback** | When VCL2 recovers, syncs DB back and deactivates VCL3 |
| **DB Sync on Failback** | VCL3 database is synced to VCL2 before deactivating |

**Monitor Script:** `~/scripts/monitor-vcl2-health.sh` on VCL3  
**Monitor Log:** `/tmp/monitor.log` on VCL3

---

### 5. Deployment on VCL3 (via deploy.yml)

| Feature | Implementation |
|---------|---------------|
| **Code Sync** | `deploy.yml` also pulls latest code to VCL3 |
| **Database Ready** | VCL3 keeps database container running with replicated data |
| **App Standby** | App container starts only during failover |

---

### 6. Load Balancer (VCL1)

| Feature | Implementation |
|---------|---------------|
| **Nginx Reverse Proxy** | Routes traffic to VCL2 (primary) or VCL3 (backup) |
| **Auto Failover** | If VCL2 fails 3 health checks, routes to VCL3 automatically |
| **Config File** | `load_balancer/nginx-load-balancer.conf` |
| **Ansible Setup** | `ansible/setup-vcl1-loadbalancer.yml` |

**Deployed to:** `/etc/nginx/sites-available/coffee-lb` on VCL1

---

## Ansible (Infrastructure as Code)

We used Ansible to automate the initial setup and configuration of all servers.

**Location:** `ansible/`

| Playbook | Purpose |
|----------|---------|
| `site.yml` | Master playbook - runs all setup playbooks |
| `0-setup-ssh-keys.yml` | Distribute SSH keys across all servers |
| `0-initial-setup.yml` | Install Docker, Node.js, and dependencies |
| `deploy.yml` | Deploy application to VCL2 |
| `deploy-vcl3-standby.yml` | Set up VCL3 as cold standby |
| `setup-vcl1-loadbalancer.yml` | Configure Nginx load balancer on VCL1 |
| `setup-vcl3-monitor.yml` | Install health monitor script on VCL3 |
| `setup-replication.yml` | Set up database replication timer on VCL2 |
| `security-hardening.yml` | Security configurations |
| `setup-firewall.yml` | Firewall rules for all servers |

**Run all setup:**
```bash
cd ansible
ansible-playbook -i inventory.yml site.yml
```

**Inventory:** `ansible/inventory.yml` contains all server IPs and SSH credentials.

---

## GitHub Secrets Required

| Secret | Purpose |
|--------|---------|
| `VCL2_SSH_PRIVATE_KEY` | SSH access to VCL2 |
| `VCL2_SSH_HOST` | VCL2 IP address |
| `VCL2_SSH_USER` | VCL2 username |
| `VCL3_SSH_PRIVATE_KEY` | SSH access to VCL3 |
| `VCL3_SSH_HOST` | VCL3 IP address |
| `VCL3_SSH_USER` | VCL3 username |

---

## Note

Some extra files in the repository (e.g., additional scripts, test playbooks) were used for debugging and testing during development. They are not part of the core functionality. Sorry for the inconvenience.