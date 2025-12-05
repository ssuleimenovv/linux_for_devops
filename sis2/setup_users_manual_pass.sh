#!/bin/bash
# ========================================================
# Script: setup_users_manual_pass.sh
# Purpose: Create roles, users, groups and set permissions
# Author: Suleimenov Ayan
# ========================================================

# === CREATE GROUPS ===
echo "Creating groups..."
sudo groupadd admins       # group for administrators
sudo groupadd auditors     # group for auditors
sudo groupadd automation   # group for automation bots
sudo groupadd postgres_grp # group for PostgreSQL service user
sudo groupadd web          # group for web service user

# === CREATE USERS ===
echo "Creating users..."
sudo useradd -m -s /bin/bash admin1    -g admins        # admin user
sudo useradd -m -s /bin/bash auditor1  -g auditors      # auditor user
sudo useradd -m -s /bin/bash autobot   -g automation    # automation bot user
sudo useradd -m -s /bin/bash pguser    -g postgres_grp  # PostgreSQL service user
sudo useradd -m -s /bin/bash webuser   -g web           # web service user

# === REQUIRE PASSWORD CHANGE ===
# Force new users to change password at first login
echo "Enforcing manual password setup..."
sudo passwd -e admin1
sudo passwd -e auditor1
sudo passwd -e autobot
sudo passwd -e pguser
sudo passwd -e webuser

# === SET PERMISSIONS ===
echo "Configuring permissions..."
# Admin gets full sudo
sudo usermod -aG sudo admin1

# Auditor gets read access to logs
sudo setfacl -m u:auditor1:r /var/log/syslog

# Autobot gets limited sudo rights
echo "autobot ALL=(ALL) NOPASSWD:/bin/systemctl restart nginx" | sudo tee /etc/sudoers.d/autobot

# === SSH SETUP FOR AUTOBOT ===
echo "Setting up SSH for autobot..."
sudo -u autobot mkdir -p /home/autobot/.ssh
sudo -u autobot ssh-keygen -t rsa -b 4096 -f /home/autobot/.ssh/id_rsa -N ""
cat /home/autobot/.ssh/id_rsa.pub | sudo tee -a /home/autobot/.ssh/authorized_keys
sudo chmod 700 /home/autobot/.ssh
sudo chmod 600 /home/autobot/.ssh/authorized_keys

# === VERIFY ===
echo "Verification..."
id admin1
id auditor1
id autobot
id pguser
id webuser

echo "=== Script completed successfully ==="
