# Firewall Configuration for New Developers

## Why This is Important

When a new developer gets fresh VCL machines, the firewall (iptables/UFW) might block access to port 3000, preventing the app from being accessible even though it's running.

**Problem Without Firewall Setup:**
```bash
# App is running
docker ps  # Shows coffee_app running on port 3000

# But you can't access it!
curl http://152.7.178.106:3000  # Connection refused
```

**Solution:** Ansible automatically configures firewall rules to open necessary ports.

---

## What Ansible Does Automatically

When you run `ansible-playbook -i inventory.yml site.yml`, it:

### 1. Clears Existing iptables Rules
```bash
# Removes any conflicting firewall rules
iptables -F
iptables -X
```

### 2. Installs UFW (Uncomplicated Firewall)
```bash
sudo apt install ufw
```

### 3. Opens Required Ports

#### On VCL1 (Load Balancer):
- **Port 22** - SSH access
- **Port 80** - HTTP traffic (load balancer)
- **Port 3000** - App access (load balancer also listens here)

#### On VCL2 (Primary App):
- **Port 22** - SSH access
- **Port 3000** - Coffee app
- **Port 5432** - PostgreSQL (for database replication)

#### On VCL3 (Standby App):
- **Port 22** - SSH access
- **Port 3000** - Coffee app (standby mode)
- **Port 5432** - PostgreSQL (receives replicated data)

### 4. Blocks All Other Traffic
- Default policy: **DENY** incoming
- Default policy: **ALLOW** outgoing

---

## Manual Firewall Setup (If Not Using site.yml)

If you want to just configure the firewall without running the full setup:

```bash
cd ansible
ansible-playbook -i inventory.yml setup-firewall.yml
```

This takes about 30 seconds and configures firewall on all 3 servers.

---

## Verify Firewall Configuration

### Check UFW Status
```bash
# On VCL2
ssh vcl2 'sudo ufw status verbose'

# Expected output:
# Status: active
# To                         Action      From
# --                         ------      ----
# 22/tcp                     ALLOW       Anywhere
# 3000/tcp                   ALLOW       Anywhere
# 5432/tcp                   ALLOW       Anywhere
```

### Check Specific Port
```bash
# Test if port 3000 is open
nc -zv 152.7.178.106 3000

# Expected: "Connection to 152.7.178.106 3000 port [tcp/*] succeeded!"
```

### Check iptables Rules
```bash
ssh vcl2 'sudo iptables -L -n'

# Shows detailed firewall rules
```

---

## Troubleshooting

### Problem: Port 3000 Still Blocked After Running Ansible

**Check if UFW is enabled:**
```bash
ssh vcl2 'sudo ufw status'
```

**If inactive, enable it:**
```bash
ssh vcl2 'sudo ufw enable'
```

---

### Problem: Can't Access App From Browser

**Test from VCL2 itself (should work):**
```bash
ssh vcl2 'curl http://localhost:3000/coffees'
```

**Test from external (might be blocked by NCSU network):**
```bash
curl http://152.7.178.106:3000/coffees
```

**If local works but external doesn't:**
- NCSU VCL network might have additional firewall rules
- Try accessing from VPN or within VCL network
- Load balancer (VCL1) should handle external access

---

### Problem: Accidentally Blocked SSH

**If you get locked out via SSH:**
```bash
# Contact VCL support to access via console
# Then reset firewall:
sudo ufw disable
sudo ufw reset
sudo ufw allow 22
sudo ufw enable
```

---

## Security Best Practices

### What We Block (Good!)
- ❌ All random ports (only specific ports allowed)
- ❌ Port 3306 (MySQL - we use PostgreSQL on 5432)
- ❌ Port 8080 (not needed)
- ❌ Port 6379 (Redis - not used in this project)

### What We Allow (Necessary!)
- ✅ Port 22 - SSH (need to access servers)
- ✅ Port 80 - HTTP (load balancer)
- ✅ Port 3000 - App (coffee app)
- ✅ Port 5432 - PostgreSQL (database replication)

---

## For New Developers

When you set up on new VCL machines:

### Option 1: Use site.yml (Recommended)
```bash
ansible-playbook -i inventory.yml site.yml
```
✅ **Firewall is configured automatically** as first step

### Option 2: Manual Firewall Setup Only
```bash
ansible-playbook -i inventory.yml setup-firewall.yml
```
✅ **Quick firewall setup** (30 seconds)

### Option 3: Manual Commands (Not Recommended)
```bash
# On each VCL machine, run:
ssh vcl2
sudo ufw allow 22
sudo ufw allow 3000
sudo ufw allow 5432
sudo ufw enable
exit
```
❌ **Tedious and error-prone** - Use Ansible instead!

---

## Port Reference Table

| Port | Service | VCL1 | VCL2 | VCL3 | Why |
|------|---------|------|------|------|-----|
| 22   | SSH     | ✅   | ✅   | ✅   | Remote access |
| 80   | HTTP    | ✅   | ❌   | ❌   | Load balancer only |
| 3000 | App     | ✅   | ✅   | ✅   | Coffee application |
| 5432 | PostgreSQL | ❌ | ✅   | ✅   | Database & replication |

---

## Summary

✅ **Ansible handles all firewall configuration automatically**

✅ **No manual iptables/UFW commands needed**

✅ **Works on fresh VCL machines out of the box**

✅ **Secure by default** (only necessary ports open)

When a new developer runs `ansible-playbook -i inventory.yml site.yml`, they get:
- Firewall configured ✅
- Ports opened ✅
- App accessible ✅
- Database replication working ✅
- All in one command! ✅

**No firewall troubleshooting needed!** 🎯
