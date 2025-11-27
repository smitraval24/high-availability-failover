# NCSU Student Guide - DevOps Infrastructure Setup

This guide will help you set up a complete production-ready infrastructure on VCL machines using Ansible automation.

## 🎯 What You'll Build

- **VCL1**: Nginx Load Balancer
- **VCL2**: Primary Application Server with PostgreSQL Database
- **VCL3**: Standby Server with Automatic Failover Monitoring

## 📋 Prerequisites

1. **3 VCL Ubuntu machines** (Ubuntu 20.04 or 22.04)
2. **Your NCSU Unity credentials** (same password for all VCLs)
3. **SSH access** to all 3 VCLs

## 🚀 Quick Start (3 Steps)

### Step 1: Update Configuration Files

On your **local machine**, update the IP addresses and username in two files:

**File 1: `ansible/inventory.yml`**
```yaml
all:
  hosts:
    vcl1:
      ansible_host: YOUR_VCL1_IP  # Change this
      ansible_user: YOUR_UNITY_ID  # Change this
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519

    vcl2:
      ansible_host: YOUR_VCL2_IP  # Change this
      ansible_user: YOUR_UNITY_ID  # Change this
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519

    vcl3:
      ansible_host: YOUR_VCL3_IP  # Change this
      ansible_user: YOUR_UNITY_ID  # Change this
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519
```

**File 2: `ansible/inventory-password.yml`**
```yaml
all:
  hosts:
    vcl1:
      ansible_host: YOUR_VCL1_IP  # Change this
      ansible_user: YOUR_UNITY_ID  # Change this

    vcl2:
      ansible_host: YOUR_VCL2_IP  # Change this
      ansible_user: YOUR_UNITY_ID  # Change this

    vcl3:
      ansible_host: YOUR_VCL3_IP  # Change this
      ansible_user: YOUR_UNITY_ID  # Change this
```

### Step 2: Copy Project to VCL2

SSH into VCL2 and clone the repository:

```bash
# SSH into VCL2
ssh YOUR_UNITY_ID@YOUR_VCL2_IP

# Clone the repository
git clone https://github.ncsu.edu/YOUR_REPO/devops-project.git
cd devops-project/ansible
```

### Step 3: Run the Setup Script

From VCL2, run the automated setup:

```bash
bash SETUP.sh
```

**That's it!** The script will:
1. Ask for your password once
2. Fix any connectivity issues automatically
3. Setup SSH keys for passwordless access
4. Deploy the complete infrastructure (15-20 minutes)

## 🔧 Using Your Own Application

Want to deploy your own app instead of the Coffee project?

### Option 1: Replace the Coffee Project

1. Update `deploy.yml` to point to your repository:
```yaml
- name: Pull latest code from GitHub
  shell: |
    cd /home/{{ ansible_user }}/YOUR_PROJECT_NAME
    git pull origin main
```

2. Update docker-compose paths:
```yaml
- name: Build and start new containers
  shell: |
    cd /home/{{ ansible_user }}/YOUR_PROJECT_NAME
    sudo docker-compose up -d --build
```

### Option 2: Create a New Deployment Playbook

Create `ansible/deploy-myapp.yml`:

```yaml
---
- name: Deploy My Application
  hosts: vcl2
  gather_facts: no

  tasks:
    - name: Clone my repository
      git:
        repo: 'https://github.ncsu.edu/YOUR_UNITY_ID/your-app.git'
        dest: '/home/{{ ansible_user }}/your-app'
        version: main

    - name: Build and deploy with Docker
      shell: |
        cd /home/{{ ansible_user }}/your-app
        sudo docker-compose up -d --build
```

Then update `site.yml` to use your playbook:
```yaml
# Step 4: Deploy Application to VCL2
- name: Deploy Application to VCL2
  import_playbook: deploy-myapp.yml  # Changed from deploy.yml
```

## 📁 Project Structure

```
ansible/
├── SETUP.sh                    # Main automated setup script
├── inventory.yml               # Server inventory (SSH keys)
├── inventory-password.yml      # Server inventory (passwords)
├── 0-fix-connectivity.yml      # Fix firewall/iptables issues
├── 0-initial-setup.yml         # Setup SSH keys
├── site.yml                    # Master orchestration playbook
├── deploy.yml                  # Application deployment
├── setup-vcl1-loadbalancer.yml # Load balancer configuration
├── setup-vcl3-monitor.yml      # Failover monitoring
├── setup-replication.yml       # Database replication
├── security-hardening.yml      # Security configuration
├── health-check.yml            # System health checks
└── setup-firewall.yml          # Firewall rules
```

## 🛠️ Manual Steps (If SETUP.sh Fails)

### Step 1: Fix Connectivity
```bash
ansible-playbook -i inventory-password.yml 0-fix-connectivity.yml --ask-pass
```

### Step 2: Setup SSH Keys
```bash
ansible-playbook -i inventory-password.yml 0-initial-setup.yml --ask-pass
```

### Step 3: Deploy Infrastructure
```bash
ansible-playbook -i inventory.yml site.yml
```

## ✅ Testing Your Infrastructure

After setup completes:

### Test Load Balancer
```bash
curl http://YOUR_VCL1_IP/coffees
```

### Test Primary App (VCL2)
```bash
curl http://YOUR_VCL2_IP:3000/coffees
```

### Check Failover Monitor
```bash
ssh vcl3 'sudo systemctl status vcl2-monitor'
```

### View Database Replication Logs
```bash
ssh vcl2 'tail -f /var/log/db-replication.log'
```

### Test Failover
```bash
# Stop VCL2 app
ssh vcl2 'cd ~/devops-project/coffee_project && sudo docker-compose down'

# Wait 30 seconds, VCL3 should auto-activate
sleep 30

# Test load balancer (should still work via VCL3)
curl http://YOUR_VCL1_IP/coffees
```

## 🐛 Troubleshooting

### "Connection timeout" errors
The `0-fix-connectivity.yml` playbook should handle this automatically. If issues persist:
```bash
# Manually clear iptables on each VCL
ssh YOUR_UNITY_ID@VCL_IP "sudo iptables -F && sudo iptables -P INPUT ACCEPT"
```

### "Permission denied" errors
Make sure you're using the correct Unity ID and password:
```bash
# Test SSH connection
ssh YOUR_UNITY_ID@YOUR_VCL_IP
```

### "sshpass not found"
```bash
sudo apt-get update
sudo apt-get install -y sshpass
```

### VCL1 unreachable during deployment
Run the connectivity fix playbook again:
```bash
ansible-playbook -i inventory-password.yml 0-fix-connectivity.yml --ask-pass
```

## 📚 Understanding the Components

### Load Balancer (VCL1)
- **Nginx** routes traffic between VCL2 (primary) and VCL3 (backup)
- Automatic failover when VCL2 is down
- Health checks every 10 seconds

### Primary Server (VCL2)
- **Docker containers** running your application and PostgreSQL
- **Database replication** to VCL3 every 30 minutes via cron
- **SSH keys** for passwordless communication with VCL3

### Standby Server (VCL3)
- **Systemd service** monitors VCL2 health every 10 seconds
- **Auto-activation** after 3 consecutive health check failures
- **Auto-deactivation** when VCL2 recovers
- **Database sync** from VCL2 every 30 minutes

### Security
- **UFW firewall** enabled on all servers
- **fail2ban** protecting against brute force attacks
- **Automatic security updates** enabled
- **SSH hardening** (disable root login, key-only auth)

## 🎓 Learning Outcomes

By completing this setup, you'll gain hands-on experience with:

1. **Infrastructure as Code (IaC)** - Ansible playbooks
2. **Load Balancing** - Nginx upstream configuration
3. **High Availability** - Automatic failover systems
4. **Database Replication** - PostgreSQL backup/restore
5. **Container Orchestration** - Docker and Docker Compose
6. **Security Hardening** - Firewalls, fail2ban, SSH keys
7. **System Monitoring** - Health checks, systemd services
8. **CI/CD Concepts** - Automated deployment pipelines

## 📝 Customization Ideas

1. **Add more app servers** - Update inventory to include vcl4, vcl5, etc.
2. **Change replication frequency** - Edit cron job in `setup-replication.yml`
3. **Add SSL/HTTPS** - Configure Let's Encrypt in load balancer
4. **Add monitoring** - Integrate Prometheus/Grafana
5. **Add logging** - Setup ELK stack (Elasticsearch, Logstash, Kibana)
6. **Different database** - Replace PostgreSQL with MongoDB, MySQL, etc.

## 🤝 Contributing

Found a bug or have improvements? Submit a pull request!

## 📧 Support

For NCSU-specific issues, contact your TA or instructor.

For technical issues with the playbooks, check the repository issues page.

---

**Happy DevOps Learning! 🚀**
