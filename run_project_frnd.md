# Project Setup Guide for Friends

Here is the complete guide to run the project setup from scratch. It covers everything from the local setup to running the automation on the VCL machine.

first step before running these steps below is to run the local-bootstrap.sh from the scripts folder on your local machine

### **Step 1: Local Setup (On Your Laptop)**

Before doing anything on the servers, you need to update the configuration files with your specific VCL details.

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

### **Step 2: Server Setup (On VCL 2)**

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
    This saves your password so the automation scripts don't get stuck asking for it.
    ```bash
    # Enable credential caching for 1 hour
    git config --global credential.helper cache
    git config --global credential.helper 'cache --timeout=3600'

    # Run a pull to trigger the login prompt and save it
    git pull
    # (Enter your Username and Personal Access Token here)

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
    *   **Note:** When it asks for the "VCL Password", enter the password you use to SSH into the VCL machines.

---

### **Step 3: Verify It Works**

Once the script finishes successfully:

1.  **Check the Website (Load Balancer):**
    ```bash
    curl -v http://152.7.176.221
    ```
    *(Replace with your VCL 1 IP. You should see the HTML for the Coffee App)*
