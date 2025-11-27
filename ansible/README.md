# Ansible Infrastructure Automation

Complete infrastructure automation for the Coffee App using Ansible. This setup manages load balancing, failover, database replication, security, and deployments across three servers.

## Infrastructure Overview

```
VCL1 (152.7.178.184) - Load Balancer
  ├── Nginx load balancer
  └── Routes traffic to VCL2 (primary) and VCL3 (backup)

VCL2 (152.7.178.106) - Primary Application
  ├── Coffee app running
  ├── PostgreSQL database
  └── Database replication to VCL3 every 30 min

VCL3 (152.7.178.91) - Standby Application
  ├── Health monitor watching VCL2
  ├── Auto-failover if VCL2 fails
  └── Database synced from VCL2
```

## Available Playbooks

### 1. `site.yml` - Complete Infrastructure Setup
**Use this to setup everything from scratch to production**

```bash
ansible-playbook -i inventory.yml site.yml
```

This master playbook runs all the following in order:
- **Configures firewall rules** (opens ports 22, 80, 3000, 5432)
- Installs Docker on all servers
- Sets up SSH keys
- Configures load balancer on VCL1
- Deploys app to VCL2
- Sets up database replication
- Configures failover monitoring on VCL3
- Applies security hardening
- Runs health checks

### 2. `deploy.yml` - Deploy Application to VCL2
Deploy or update the coffee app on VCL2:

```bash
ansible-playbook -i inventory.yml deploy.yml
```

**What it does:**
- Pulls latest code from GitHub
- Stops old containers
- Builds and starts new containers
- Runs health checks

### 3. `setup-vcl1-loadbalancer.yml` - Configure Load Balancer
Setup Nginx load balancer on VCL1:

```bash
ansible-playbook -i inventory.yml setup-vcl1-loadbalancer.yml
```

**What it does:**
- Installs Nginx
- Configures upstream servers (VCL2 primary, VCL3 backup)
- Sets up health checks
- Enables automatic failover

### 4. `setup-vcl3-monitor.yml` - Setup Failover Monitor
Configure VCL3 to monitor VCL2 and auto-activate on failure:

```bash
ansible-playbook -i inventory.yml setup-vcl3-monitor.yml
```

**What it does:**
- Copies health monitoring script to VCL3
- Creates systemd service for monitor
- Starts monitoring VCL2
- Auto-activates VCL3 if VCL2 fails 3 consecutive checks

**Check monitor status:**
```bash
ssh vcl3 'sudo systemctl status vcl2-monitor'
ssh vcl3 'sudo journalctl -u vcl2-monitor -f'
```

### 5. `setup-replication.yml` - Database Replication
Setup automatic database replication from VCL2 to VCL3:

```bash
ansible-playbook -i inventory.yml setup-replication.yml
```

**What it does:**
- Creates database sync script
- Sets up SSH keys for passwordless replication
- Configures cron job (runs every 30 minutes)
- Tests initial replication

**Manual replication:**
```bash
ssh vcl2 '/home/vpatel29/scripts/sync-db-to-vcl3.sh'
```

**Check replication logs:**
```bash
ssh vcl2 'tail -f /var/log/db-replication.log'
```

### 6. `health-check.yml` - Health Check All Servers
Verify all infrastructure components are working:

```bash
ansible-playbook -i inventory.yml health-check.yml
```

**What it checks:**
- VCL1: Nginx status, load balancer config, proxy functionality
- VCL2: Docker status, app health, database connectivity
- VCL3: Monitor service status, standby readiness

**Check specific server:**
```bash
ansible-playbook -i inventory.yml health-check.yml --limit vcl1
ansible-playbook -i inventory.yml health-check.yml --limit vcl2
ansible-playbook -i inventory.yml health-check.yml --limit vcl3
```

### 7. `setup-firewall.yml` - Configure Firewall Rules
Setup firewall and open required ports on all servers:

```bash
ansible-playbook -i inventory.yml setup-firewall.yml
```

**What it does:**
- Installs UFW (Uncomplicated Firewall)
- Clears existing iptables rules
- Opens required ports:
  - **VCL1**: 22 (SSH), 80 (HTTP), 3000 (App)
  - **VCL2**: 22 (SSH), 3000 (App), 5432 (PostgreSQL)
  - **VCL3**: 22 (SSH), 3000 (App), 5432 (PostgreSQL)
- Blocks all other incoming traffic
- Allows all outgoing traffic

**Check firewall status:**
```bash
ssh vcl2 'sudo ufw status verbose'
ssh vcl3 'sudo ufw status verbose'
```

### 8. `security-hardening.yml` - Security Hardening
Apply security best practices to all servers:

```bash
ansible-playbook -i inventory.yml security-hardening.yml
```

**What it does:**
- Updates all packages
- Configures UFW firewall (includes firewall rules)
- Installs and configures fail2ban
- Disables root login
- Disables password authentication
- Enables automatic security updates

**Check security status:**
```bash
ssh vcl1 'sudo ufw status'
ssh vcl1 'sudo fail2ban-client status'
```

## Quick Start

### One-Command Complete Setup
```bash
ansible-playbook -i inventory.yml site.yml
```

### Step-by-Step Setup
```bash
# 1. Configure firewall (IMPORTANT: Do this first!)
ansible-playbook -i inventory.yml setup-firewall.yml

# 2. Setup load balancer
ansible-playbook -i inventory.yml setup-vcl1-loadbalancer.yml

# 3. Deploy application
ansible-playbook -i inventory.yml deploy.yml

# 4. Setup database replication
ansible-playbook -i inventory.yml setup-replication.yml

# 5. Setup failover monitor
ansible-playbook -i inventory.yml setup-vcl3-monitor.yml

# 6. Apply security hardening
ansible-playbook -i inventory.yml security-hardening.yml

# 7. Verify everything
ansible-playbook -i inventory.yml health-check.yml
```

## Testing

### Dry Run (Preview Changes)
```bash
ansible-playbook -i inventory.yml deploy.yml --check
```

### Verbose Output (Debugging)
```bash
ansible-playbook -i inventory.yml deploy.yml -vvv
```

### Test Connectivity
```bash
ansible -i inventory.yml all -m ping
```

### Test Specific Server
```bash
ansible -i inventory.yml vcl1 -m ping
ansible -i inventory.yml vcl2 -m ping
ansible -i inventory.yml vcl3 -m ping
```

## Common Tasks

### Update Application
```bash
ansible-playbook -i inventory.yml deploy.yml
```

### Check System Health
```bash
ansible-playbook -i inventory.yml health-check.yml
```

### Manual Failover Test
```bash
# Stop VCL2 app
ssh vcl2 'cd ~/devops-project/coffee_project && sudo docker-compose down'

# Wait 30 seconds and check VCL3
ssh vcl3 'sudo journalctl -u vcl2-monitor -n 20'

# VCL3 should auto-activate
curl http://152.7.178.184/coffees
```

### Manual Database Sync
```bash
ssh vcl2 '/home/vpatel29/scripts/sync-db-to-vcl3.sh'
```

## Installation

### Install Ansible
```bash
# On Ubuntu/Debian
sudo apt update
sudo apt install ansible -y

# Verify installation
ansible --version
```

### Setup SSH Keys
```bash
# Generate key if needed
ssh-keygen -t rsa -N "" -f ~/.ssh/deploy_key

# Copy to all servers
ssh-copy-id -i ~/.ssh/deploy_key vpatel29@152.7.178.184  # VCL1
ssh-copy-id -i ~/.ssh/deploy_key vpatel29@152.7.178.106  # VCL2
ssh-copy-id -i ~/.ssh/deploy_key vpatel29@152.7.178.91   # VCL3
```

## Comparison: GitHub Actions vs Ansible

### GitHub Actions (Existing CI/CD)
- Triggers automatically on push to main
- Handles code deployment to VCL2
- Updates VCL3 after successful deployment
- Great for continuous deployment

### Ansible (Infrastructure Management)
- Manual execution when needed
- Manages infrastructure configuration
- Handles server setup and security
- Great for infrastructure as code

**They complement each other!** GitHub Actions handles CI/CD, Ansible handles infrastructure.

## Architecture Details

### Load Balancing Strategy
- VCL2 is primary (handles all traffic normally)
- VCL3 is backup (only receives traffic if VCL2 fails)
- Nginx performs health checks every request
- Failed servers are bypassed automatically

### Failover Mechanism
- VCL3 checks VCL2 health every 10 seconds
- After 3 consecutive failures (30 seconds), activates VCL3
- When VCL2 recovers, VCL3 deactivates automatically
- All traffic continues through VCL1 load balancer

### Database Replication
- Dumps VCL2 database every 30 minutes
- Copies to VCL3 via SCP
- Restores on VCL3 automatically
- Keeps last 5 backups

## Troubleshooting

### Connection Issues
```bash
# Test SSH connectivity
ansible -i inventory.yml all -m ping

# Check if servers are reachable
ping 152.7.178.184
ping 152.7.178.106
ping 152.7.178.91
```

### Playbook Failures
```bash
# Run with verbose output
ansible-playbook -i inventory.yml <playbook>.yml -vvv

# Check syntax
ansible-playbook -i inventory.yml <playbook>.yml --syntax-check
```

### Permission Denied
```bash
# Verify SSH key
ssh -i ~/.ssh/deploy_key vpatel29@152.7.178.106

# Re-copy SSH key
ssh-copy-id -i ~/.ssh/deploy_key vpatel29@152.7.178.106
```

### Service Not Starting
```bash
# Check service status
ssh vcl3 'sudo systemctl status vcl2-monitor'

# Check logs
ssh vcl3 'sudo journalctl -u vcl2-monitor -n 50'

# Restart service
ssh vcl3 'sudo systemctl restart vcl2-monitor'
```

## Requirements

- Ansible 2.9+
- Python 3.6+
- SSH access to all servers
- Sudo privileges on servers
- SSH key at `~/.ssh/deploy_key`

## Files

- `inventory.yml` - Server definitions and groups
- `site.yml` - Master playbook (complete setup)
- `deploy.yml` - Application deployment
- `setup-vcl1-loadbalancer.yml` - Load balancer setup
- `setup-vcl3-monitor.yml` - Failover monitor setup
- `setup-replication.yml` - Database replication setup
- `setup-firewall.yml` - Firewall configuration and port management
- `health-check.yml` - Health checks for all servers
- `security-hardening.yml` - Security configuration

## Example Output

```
PLAY [Complete Infrastructure Setup] *************************

TASK [Display infrastructure setup plan] *********************
ok: [localhost]

TASK [Install Docker on All Servers] ************************
changed: [vcl1]
changed: [vcl2]
changed: [vcl3]

TASK [Configure Load Balancer] *******************************
changed: [vcl1]

TASK [Deploy Application to VCL2] ****************************
changed: [vcl2]

TASK [Setup Database Replication] ****************************
changed: [vcl2]

TASK [Setup VCL3 Failover Monitor] ***************************
changed: [vcl3]

TASK [Apply Security Hardening] ******************************
changed: [vcl1]
changed: [vcl2]
changed: [vcl3]

PLAY RECAP ***************************************************
vcl1  : ok=15  changed=8   failed=0
vcl2  : ok=18  changed=10  failed=0
vcl3  : ok=12  changed=7   failed=0
```

## Next Steps

After running the playbooks:

1. **Test Load Balancer:**
   ```bash
   curl http://152.7.178.184/coffees
   ```

2. **Monitor VCL3:**
   ```bash
   ssh vcl3 'sudo systemctl status vcl2-monitor'
   ```

3. **Check Replication:**
   ```bash
   ssh vcl2 'tail -f /var/log/db-replication.log'
   ```

4. **Verify Security:**
   ```bash
   ssh vcl1 'sudo ufw status'
   ```
