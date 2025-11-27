# Simple Setup Guide - For Brand New VCL Machines

## 🚀 Complete Setup in Just 2 Commands!

This guide is for setting up the project on **brand new VCL machines** with **zero configuration**.

### Your VCL Machines
- **VCL1**: 152.7.177.129 (Load Balancer)
- **VCL2**: 152.7.176.221 (Primary App)
- **VCL3**: 152.7.178.104 (Standby App)

---

## Prerequisites

You need:
1. SSH access to all 3 VCL machines from your laptop
2. VCL password
3. That's it!

---

## Complete Setup (On VCL2)

### Step 1: Install Ansible and Clone Repo

```bash
# SSH to VCL2
ssh sraval@152.7.176.221

# Install Ansible and sshpass
sudo apt update && sudo apt install ansible sshpass -y

# Clone repository
git clone https://github.ncsu.edu/vpatel29/devops-project.git
cd devops-project/ansible
```

### Step 2: Update Inventory with Your IPs

```bash
# Update inventory.yml with your VCL IPs
cat > inventory.yml << 'EOF'
all:
  hosts:
    vcl1:
      ansible_host: 152.7.177.129
      ansible_user: sraval
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519

    vcl2:
      ansible_host: 152.7.176.221
      ansible_user: sraval
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519

    vcl3:
      ansible_host: 152.7.178.104
      ansible_user: sraval
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519

  children:
    load_balancer:
      hosts:
        vcl1:

    app_servers:
      hosts:
        vcl2:
        vcl3:
EOF

# Update inventory-password.yml
cat > inventory-password.yml << 'EOF'
all:
  hosts:
    vcl1:
      ansible_host: 152.7.177.129
      ansible_user: sraval
      ansible_connection: ssh
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

    vcl2:
      ansible_host: 152.7.176.221
      ansible_user: sraval
      ansible_connection: ssh
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

    vcl3:
      ansible_host: 152.7.178.104
      ansible_user: sraval
      ansible_connection: ssh
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

  children:
    load_balancer:
      hosts:
        vcl1:

    app_servers:
      hosts:
        vcl2:
        vcl3:

  vars:
    ansible_python_interpreter: /usr/bin/python3
EOF
```

### Step 3: Run Initial Setup (Password Required - ONCE!)

```bash
ansible-playbook -i inventory-password.yml 0-initial-setup.yml --ask-pass --ask-become-pass
```

**Enter your VCL password when prompted.**

This will automatically:
- ✅ Clear all iptables rules on all VCLs
- ✅ Disable UFW on all VCLs
- ✅ Generate SSH keys
- ✅ Distribute SSH keys to all VCLs
- ✅ Enable passwordless authentication

**Takes: ~2 minutes**

### Step 4: Deploy Complete Infrastructure (No Password!)

```bash
ansible-playbook -i inventory.yml site.yml
```

Press **Enter** when prompted.

This will automatically:
- ✅ Install Docker on all servers
- ✅ Configure load balancer on VCL1
- ✅ Deploy app on VCL2
- ✅ Setup failover monitoring on VCL3
- ✅ Configure database replication
- ✅ Setup firewalls (with proper security rules!)
- ✅ Apply security hardening

**Takes: ~15-20 minutes**

---

## That's It!

After these 2 commands, your complete infrastructure is ready:

```
✅ VCL1 (Load Balancer):  http://152.7.177.129
✅ VCL2 (Primary App):    http://152.7.176.221:3000
✅ VCL3 (Standby):        Monitoring VCL2, auto-failover enabled
```

---

## Test Your Setup

```bash
# Test load balancer
curl http://152.7.177.129/coffees

# Test app directly
curl http://152.7.176.221:3000/coffees

# Run health check
ansible-playbook -i inventory.yml health-check.yml
```

---

## What Makes This Automatic?

### Old Way (Manual):
1. SSH to VCL1 → Disable firewall → Install packages → Configure
2. SSH to VCL2 → Disable firewall → Install packages → Configure
3. SSH to VCL3 → Disable firewall → Install packages → Configure
4. Setup SSH keys manually between servers
5. Configure load balancer manually
6. Deploy app manually
7. Setup failover manually

**Time:** 3-4 hours, error-prone ❌

### New Way (Automated):
1. Run `0-initial-setup.yml` (password once) ← **Handles all firewall/SSH issues automatically**
2. Run `site.yml` (no password)

**Time:** 20 minutes, zero errors ✅

---

## The Magic of `0-initial-setup.yml`

This playbook automatically fixes common issues on brand new VCL machines:

```yaml
- Flush iptables rules     # Fixes "No route to host"
- Disable UFW              # Fixes firewall blocking
- Install Python3          # Fixes missing dependencies
- Generate SSH keys        # Fixes no key exists
- Distribute keys          # Fixes password authentication
- Test connections         # Verifies everything works
```

All using password authentication, so it works on **completely fresh VCL machines with zero setup**!

---

## For New Developers

When a new developer gets fresh VCL machines, they just:

1. **Update IPs** in `inventory.yml` and `inventory-password.yml`
2. **Run 2 commands**:
   ```bash
   ansible-playbook -i inventory-password.yml 0-initial-setup.yml --ask-pass --ask-become-pass
   ansible-playbook -i inventory.yml site.yml
   ```
3. **Done!** Complete infrastructure ready.

---

## Timeline Summary

| Task | Command | Password? | Time |
|------|---------|-----------|------|
| Install Ansible | `sudo apt install ansible sshpass -y` | Yes (sudo) | 1 min |
| Clone repo | `git clone ...` | No | 1 min |
| Initial setup | `0-initial-setup.yml` | Yes (VCL password) | 2 min |
| Deploy infrastructure | `site.yml` | No | 15-20 min |
| **TOTAL** | | | **~20-25 minutes** |

---

## Troubleshooting

### Problem: "Permission denied" on initial setup

**Solution:** Make sure sshpass is installed:
```bash
sudo apt install sshpass -y
```

### Problem: "Unreachable" errors

**Solution:** Make sure you can SSH to all VCLs from Windows:
```bash
ssh sraval@152.7.177.129
ssh sraval@152.7.178.104
```

If Windows can reach them, Ansible will too!

---

## Summary

**Before:** Manual setup, hours of work, error-prone

**After:** 2 Ansible commands, ~20 minutes, fully automated

The `0-initial-setup.yml` playbook automatically handles:
- Firewalls (iptables, UFW)
- SSH keys
- Permissions
- All the annoying edge cases

You just provide the password once, and everything else is automatic! 🎯
