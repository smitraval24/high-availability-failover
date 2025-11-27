# Easy Setup Guide - Password-Based Ansible Setup

## 🎯 The Easiest Way to Setup Everything

This method lets you setup everything using your VCL password. You only need to type your password ONCE, then Ansible handles everything else automatically!

---

## Your VCL Machines

- **VCL1**: 152.7.177.129 (Load Balancer)
- **VCL2**: 152.7.176.221 (Primary App)
- **VCL3**: 152.7.178.104 (Standby App)
- **Username**: sraval

---

## Complete Setup (Just 3 Commands!)

### Step 1: SSH to VCL2 and Install Ansible

```bash
# SSH to VCL2 from Windows
ssh sraval@152.7.176.221

# Install Ansible
sudo apt update && sudo apt install ansible -y

# Clone repository
git clone https://github.ncsu.edu/vpatel29/devops-project.git
cd devops-project/ansible
```

---

### Step 2: Setup SSH Keys (Enter Password Once)

This command will ask for your password ONCE, then setup passwordless SSH to all 3 VCLs:

```bash
ansible-playbook -i inventory-password.yml 0-setup-ssh-keys.yml --ask-pass --ask-become-pass
```

**When prompted:**
- `SSH password:` → Enter your VCL password (sraval's password)
- `BECOME password:` → Enter the same password again

**What this does:**
1. ✅ Generates SSH key on VCL2
2. ✅ Disables firewalls on all 3 VCLs
3. ✅ Copies SSH key to all 3 VCLs
4. ✅ Tests passwordless connection

---

### Step 3: Run Complete Infrastructure Setup (No Password!)

Now you can run the complete setup WITHOUT entering any password:

```bash
ansible-playbook -i inventory.yml site.yml
```

Press **Enter** when it asks to continue, and watch Ansible build your entire infrastructure!

**What this does:**
- ✅ Configures firewalls (with proper security)
- ✅ Installs Docker on all servers
- ✅ Configures load balancer on VCL1
- ✅ Deploys app on VCL2
- ✅ Sets up failover on VCL3
- ✅ Configures database replication
- ✅ Applies security hardening

---

## Timeline

- **Step 1**: 2 minutes (install Ansible, clone repo)
- **Step 2**: 2 minutes (setup SSH keys - password required)
- **Step 3**: 15-20 minutes (complete infrastructure setup - no password!)

**Total: ~20-25 minutes** 🚀

---

## Complete Command Sequence

Copy and paste these commands on VCL2:

```bash
# Install Ansible
sudo apt update && sudo apt install ansible -y

# Clone repo
git clone https://github.ncsu.edu/vpatel29/devops-project.git
cd devops-project/ansible

# Setup SSH keys (will ask for password)
ansible-playbook -i inventory-password.yml 0-setup-ssh-keys.yml --ask-pass --ask-become-pass

# Run complete setup (no password needed now!)
ansible-playbook -i inventory.yml site.yml
```

---

## How It Works

### Traditional Way (Manual):
```
You → SSH to VCL1 with password
You → Manually configure stuff
You → SSH to VCL2 with password
You → Manually configure stuff
You → SSH to VCL3 with password
You → Manually configure stuff
(Takes hours, error-prone)
```

### Ansible Way (This Method):
```
You → Enter password ONCE
Ansible → Generates SSH keys
Ansible → Copies keys to all VCLs
Ansible → Configures everything automatically
(Takes 20 minutes, no errors!)
```

---

## Verification

After setup completes, test everything:

```bash
# Test app on VCL2
curl http://152.7.176.221:3000/coffees

# Test load balancer on VCL1
curl http://152.7.177.129/coffees

# Check all services
ansible-playbook -i inventory.yml health-check.yml
```

✅ **Expected:** JSON response with coffee data

---

## Troubleshooting

### Problem: "Permission denied" when running playbook

**Cause:** Ansible can't connect with password

**Solution:** Make sure you can SSH manually first:
```bash
ssh sraval@152.7.177.129  # Test VCL1
ssh sraval@152.7.178.104  # Test VCL3
```

If manual SSH works, try the playbook again.

---

### Problem: "Failed to connect to the host via ssh"

**Cause:** Firewall blocking SSH

**Solution:** SSH to each VCL manually and disable firewall:
```bash
# On each VCL
sudo ufw disable
```

Then run the setup playbook again.

---

### Problem: Playbook asks for password multiple times

**Cause:** Using wrong inventory file

**Solution:**
- For FIRST run (SSH keys setup): Use `inventory-password.yml` with `--ask-pass`
- For ALL OTHER runs: Use `inventory.yml` (no password needed)

---

## Why This Approach is Better

### ❌ Manual Setup:
- Type password 50+ times
- Easy to make mistakes
- Hard to reproduce
- Takes hours

### ✅ Ansible Setup (This Method):
- Type password ONCE (or ZERO if firewall already off)
- No manual configuration
- Perfectly reproducible
- Takes 20 minutes

---

## Files Explained

- **`inventory-password.yml`** - Inventory for password-based auth (first run only)
- **`inventory.yml`** - Inventory for SSH key auth (after setup)
- **`0-setup-ssh-keys.yml`** - Playbook to setup passwordless SSH
- **`site.yml`** - Master playbook for complete infrastructure

---

## Quick Reference

### First Time Setup:
```bash
ansible-playbook -i inventory-password.yml 0-setup-ssh-keys.yml --ask-pass --ask-become-pass
```

### Complete Infrastructure:
```bash
ansible-playbook -i inventory.yml site.yml
```

### Deploy App Only:
```bash
ansible-playbook -i inventory.yml deploy.yml
```

### Health Check:
```bash
ansible-playbook -i inventory.yml health-check.yml
```

---

## Summary

**Three simple commands on VCL2:**

1. Install Ansible: `sudo apt install ansible -y`
2. Setup SSH keys: `ansible-playbook -i inventory-password.yml 0-setup-ssh-keys.yml --ask-pass --ask-become-pass`
3. Deploy infrastructure: `ansible-playbook -i inventory.yml site.yml`

**That's it!** Complete production infrastructure in 20 minutes! 🎉

---

## What You Get

After running these 3 commands:

✅ **VCL1**: Nginx load balancer routing traffic
✅ **VCL2**: Coffee app + PostgreSQL database
✅ **VCL3**: Standby mode with auto-failover
✅ **Security**: Firewalls configured properly
✅ **Monitoring**: Health checks active
✅ **Replication**: Database synced every 30 min

Access your app:
- **Load Balancer**: http://152.7.177.129/coffees
- **Direct VCL2**: http://152.7.176.221:3000/coffees

Everything automated! 🚀
