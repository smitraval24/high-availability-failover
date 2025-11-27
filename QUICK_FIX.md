# Quick Fix for VCL1 Connection Issue

## The Problem
VCL1 is unreachable due to iptables/firewall blocking SSH connections.

## The Solution
We've created automated playbooks that use password authentication to bypass firewall issues and fix everything automatically.

## Files Updated

All playbooks are now **user and IP agnostic**:
- ✅ Uses `{{ ansible_user }}` instead of hardcoded `vpatel29` or `sraval`
- ✅ Uses `{{ ansible_host }}` and `{{ hostvars }}` instead of hardcoded IPs
- ✅ Works with any NCSU student's Unity ID and VCL machines

## Run These Commands on VCL2

### Option 1: Fully Automated (Recommended)

```bash
# 1. Update the files on VCL2
cd ~/devops-project/ansible

# 2. Download the new files from your updated repo
# (You'll need to commit and push these changes first from your local machine)
git pull origin main

# 3. Run the automated setup script
bash SETUP.sh
```

The script will:
1. Ask for your password once
2. Fix VCL1, VCL2, VCL3 connectivity automatically
3. Setup SSH keys
4. Deploy complete infrastructure

**Total time: 15-20 minutes, fully automated**

---

### Option 2: Manual Step-by-Step

If you prefer manual control or the automated script fails:

```bash
cd ~/devops-project/ansible

# Step 1: Fix connectivity on all VCLs (including VCL1)
ansible-playbook -i inventory-password.yml 0-fix-connectivity.yml \
  --extra-vars "ansible_password=YOUR_PASSWORD ansible_become_password=YOUR_PASSWORD"

# Step 2: Setup SSH keys for passwordless access
ansible-playbook -i inventory-password.yml 0-initial-setup.yml \
  --extra-vars "ansible_password=YOUR_PASSWORD ansible_become_password=YOUR_PASSWORD"

# Step 3: Deploy complete infrastructure
ansible-playbook -i inventory.yml site.yml
```

---

## Before Running on VCL2

**Important:** You need to update the files on VCL2. You have two options:

### Option A: Push from Local, Pull on VCL2

From your **Windows machine**:
```bash
cd C:\NCSU\DevOps\Final_Project\devops-project
git add ansible/
git commit -m "Fix hardcoded paths and add automated connectivity fixes"
git push origin dev
```

Then on **VCL2**:
```bash
cd ~/devops-project
git pull origin dev
cd ansible
bash SETUP.sh
```

### Option B: Update Files Directly on VCL2

If you don't want to push/pull, you can copy the updated playbooks directly to VCL2.

The key files that changed:
- `ansible/0-fix-connectivity.yml` (NEW)
- `ansible/SETUP.sh` (NEW)
- `ansible/STUDENT_GUIDE.md` (NEW)
- `ansible/deploy.yml` (updated)
- `ansible/setup-replication.yml` (updated)
- `ansible/setup-vcl3-monitor.yml` (updated)
- `ansible/setup-vcl1-loadbalancer.yml` (updated)
- `ansible/site.yml` (updated)
- `ansible/README.md` (updated)

---

## What This Fixes

### 1. VCL1 Connection Issue ✅
The new `0-fix-connectivity.yml` playbook uses password authentication to connect to VCL1 and clear the firewall rules automatically.

### 2. Hardcoded Usernames ✅
Changed from `vpatel29` to `{{ ansible_user }}` in all playbooks.

### 3. Hardcoded IPs ✅
Changed from specific IPs to `{{ ansible_host }}` and `{{ hostvars['vcl1']['ansible_host'] }}`.

### 4. Future-Proof for NCSU Students ✅
Any student can now:
1. Update `inventory.yml` and `inventory-password.yml` with their VCL IPs and Unity ID
2. Run `bash SETUP.sh`
3. Everything works automatically

### 5. Easy to Use Own Application ✅
See `STUDENT_GUIDE.md` for instructions on deploying your own app instead of the Coffee project.

---

## After Setup Completes

Test your infrastructure:

```bash
# Test load balancer
curl http://152.7.177.129/coffees

# Test primary app
curl http://152.7.176.221:3000/coffees

# Check failover monitor
ssh vcl3 'sudo systemctl status vcl2-monitor'

# View database replication logs
ssh vcl2 'tail -f /var/log/db-replication.log'
```

---

## Troubleshooting

If `SETUP.sh` fails at any step, you can run the steps manually:

```bash
# Fix connectivity only
ansible-playbook -i inventory-password.yml 0-fix-connectivity.yml --ask-pass

# Setup SSH keys only
ansible-playbook -i inventory-password.yml 0-initial-setup.yml --ask-pass

# Deploy infrastructure only
ansible-playbook -i inventory.yml site.yml
```

---

**That's it! Your infrastructure should now deploy successfully on all 3 VCLs.** 🚀
