# CSC 519 - DevOps Project

This is our Coffee Project for the DevOps course. We built a full CI/CD pipeline with high availability and automatic failover between servers.

## Our Setup

We're using 3 VCL machines:

- **VCL1** (152.7.178.184) - runs nginx as a load balancer, also hosts our GitHub Actions runner
- **VCL2** (152.7.178.106) - main app server, this is where everything runs normally
- **VCL3** (152.7.178.91) - backup server, kicks in if VCL2 goes down

## What We Built

### CI/CD Pipeline

All our workflows live in `.github/workflows/`. Here's what happens:

- **Pull Requests** - runs ESLint and Jest tests automatically (`pr-test.yml`)
- **Merging to main** - deploys to VCL2 via SSH (`deploy.yml`)
- **After merge** - syncs changes back to dev branch (`sync-dev.yml`)

### Backup and Rollback

We didn't want to lose stuff if a deploy goes wrong, so:

- Before every deploy, we save a timestamped backup
- If the deploy fails, it automatically rolls back to the previous version
- All backups are stored in `~/backups/` on VCL2 if we ever need to restore manually

### Database Replication

The database on VCL2 gets synced to VCL3 every 30 seconds using a systemd timer. Basically it does a `pg_dump`, SCPs it over, and stores it in `/tmp/db-backup/`. The script is at `scripts/replicate-db.sh`.

### Failover

This was tricky to get right. VCL3 runs a health monitor (`monitor-vcl2-health.sh`) that pings VCL2 every 10 seconds. If it fails 3 times in a row (~30 sec), VCL3 automatically starts up and takes over.

When VCL2 comes back online, it syncs the database from VCL3 (in case any orders came in during downtime) and then VCL3 goes back to standby mode. The monitor logs everything to `/tmp/monitor.log`.

### Load Balancer

VCL1 runs nginx as a reverse proxy. It normally sends all traffic to VCL2, but if VCL2 fails health checks, it switches to VCL3 automatically. Config is in `load_balancer/nginx-load-balancer.conf`.

## Ansible Stuff

We used Ansible to set up all the servers so we don't have to SSH in and configure things manually every time. Everything's in the `ansible/` folder.

Main playbooks:
- `site.yml` - runs everything
- `0-setup-ssh-keys.yml` - sets up SSH keys between servers
- `0-initial-setup.yml` - installs Docker, Node, etc.
- `deploy.yml` - deploys the app to VCL2
- `deploy-vcl3-standby.yml` - gets VCL3 ready as backup
- `setup-vcl1-loadbalancer.yml` - configures nginx on VCL1
- `setup-vcl3-monitor.yml` - installs the health monitor on VCL3
- `setup-replication.yml` - sets up the DB replication timer
- `security-hardening.yml` and `setup-firewall.yml` - security stuff

To run everything:
### **Step 1: Local Setup (On Your Laptop)**

First you need to setup the ip address for the vcl machines.

1.  **Open `ansible/inventory.yml`** and update the **IP addresses** and **ansible_user** for all 3 machines:
    ```yaml
    all:
      hosts:
        vcl1:
          ansible_host: 152.7.176.221  # <--- CHANGE THIS IP
          ansible_user: your_unity_id  # <--- CHANGE THIS USER
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519

        vcl2:
          ansible_host: 152.7.177.180  # <--- CHANGE THIS IP
          ansible_user: your_unity_id  # <--- CHANGE THIS USER
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519

        vcl3:
          ansible_host: 152.7.178.104  # <--- CHANGE THIS IP
          ansible_user: your_unity_id  # <--- CHANGE THIS USER
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519
    ```

2.  **Open `ansible/inventory-password.yml`** and do the exact same updates:
    ```yaml
    all:
      hosts:
        vcl1:
          ansible_host: 152.7.176.221  # <--- CHANGE THIS IP
          ansible_user: your_unity_id  # <--- CHANGE THIS USER
          # ... keep the rest as is ...
        
        vcl2:
          ansible_host: 152.7.177.180  # <--- CHANGE THIS IP
          ansible_user: your_unity_id  # <--- CHANGE THIS USER

        vcl3:
          ansible_host: 152.7.178.104  # <--- CHANGE THIS IP
          ansible_user: your_unity_id  # <--- CHANGE THIS USER
    ```

3.  **Save and Push Changes to GitHub:**
    ```bash
    git add ansible/inventory.yml ansible/inventory-password.yml
    git commit -m "Update VCL IPs and User"
    git push
    ```

---

### **Step 2: Run this script in Local**
To congigure the communication between all the vcl machines 
You can download sshpass in your pc so when you run the script it only asks the password one time otherwise you need to enter password multiple times.
```bash
cd scripts
bash local-bootstrap.sh
```

### **Step 3: Server Setup (On VCL 2)**

We use VCL 2 as the "Control Node" to run Ansible.

1.  **SSH into VCL 2:**
    *(Replace `your_unity_id` and the IP with your VCL 2 info)*
    ```bash
    ssh your_unity_id@152.7.177.180
    ```

2.  **Clone the Repository:**
    ```bash
    git clone https://github.ncsu.edu/vpatel29/devops-project.git
    cd devops-project
    ```

3.  **Setup Git Credentials (Important!):**
    This set will save the creds. to the cache so anible can access it otherwise it would be stuck.
    ```bash
    # Enable creds caching for 1 hour
    git config --global credential.helper cache
    git config --global credential.helper 'cache --timeout=3600'

    # Run a pull to trigger login prompt and save it
    git pull
    # (Enter your github creds)

    # Run pull again to verify it works WITHOUT asking for password
    git pull
    ```

4.  **Install Ansible:**
    ```bash
    sudo apt-get update
    sudo apt-get install -y ansible sshpass
    ```

5.  **Run the Setup Script:**
    This script will handle SSH keys, firewalls, Docker, and the app deployment automatically.
    ```bash
    cd ansible
    bash SETUP.sh
    ```
    *   **Note:** It will ask for vcl password please enter the same.

---

### **Step 3: Verify It Works**

Once the script finishes successfully:

1.  **Check the Website (Load Balancer):**
    ```bash
    curl -v http://152.7.176.221
    ```
    *(Replace with your VCL 1 IP. You should see the HTML for the Coffee App)*

## GitHub Secrets

You'll need these secrets set up in the repo:

- `VCL2_SSH_PRIVATE_KEY`, `VCL2_SSH_HOST`, `VCL2_SSH_USER` - for deploying to VCL2
- `VCL3_SSH_PRIVATE_KEY`, `VCL3_SSH_HOST`, `VCL3_SSH_USER` - for syncing to VCL3

## Random Note

There's some extra scripts and test files lying around that we used while debugging. They're not really part of the main project, just stuff we tried while figuring things out. Sorry if it's a bit messy!

## Github Accounts of Collaborators

 Smit Sunilkumar Raval: sraval (ncsu account), smitraval24 (personal account)
 
 Vatsalkumar Patel: vpatel29 (ncsu account)
