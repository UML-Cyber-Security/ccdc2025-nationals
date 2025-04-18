#!/bin/bash
# WHAT IS THIS:
# Script that should be run to reinstall + configure ALL Wazuh agents. This script should work for
# all Linux types and should automatically uninstall and reinstall a Wazuh agent
# (THIS IS WIP!)

if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Must run as superuser"
  exit
fi

read -p "Select your Linux system type:
1. Debian
2. RPM
3. OpenSUSE
4. FreeBSD (WIP, try at own risk)
Enter your choice (1 or 2, 3, 4): " linux_system

if [ "$linux_system" != "1" ] && [ "$linux_system" != "2" ] && [ "$linux_system" != "3" ] && [ "$linux_system" != "4" ]; then
    echo "Invalid input. Please enter 1 or 2 or 3."
    exit 1
fi

# Uninstall original agent below
if [ "$linux_system" == "1" ]; then
    systemctl disable wazuh-agent
    apt-get remove --purge wazuh-agent
    systemctl daemon-reload
elif [ "$linux_system" == "2" ]; then
    systemctl disable wazuh-agent
    dnf remove wazuh-agent
    rm -rf /var/ossec/
    systemctl daemon-reload
elif [ "$linux_system" == "3" ]; then
    systemctl disable wazuh-agent
    zypper remove wazuh-agent
    rm -rf /var/ossec/
    systemctl daemon-reload
elif [ "$linux_system" == "4" ]; then
    service wazuh-agent stop
    pkg delete wazuh-agent
    rm -rf /var/ossec/
fi
read -p "Name of your machine: (windc, win1, linproxy, linworker1): " machine_name

read -p "Enter WAZUH MACHINE ip: " manager_ip

######################################################################
# ADD AGENT TO GROUP HERE AS WELL!
######################################################################

# Pull latest stable repo and install agent
# CHECK IF THIS IS ACTUALLY LATEST AND WORKING!
if [ "$linux_system" == "1" ]; then
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
    apt-get update
    WAZUH_MANAGER=$manager_ip WAZUH_AGENT_NAME=$machine_name apt-get install wazuh-agent
elif [ "$linux_system" == "2" ] || [ "$linux_system" == "3" ]; then
    curl -o wazuh-agent-4.11.2-1.x86_64.rpm https://packages.wazuh.com/4.x/yum/wazuh-agent-4.11.2-1.x86_64.rpm
    sudo WAZUH_MANAGER=$manager_ip WAZUH_AGENT_NAME=$machine_name rpm -ihv wazuh-agent-4.11.2-1.x86_64.rpm
elif [ "$linux_system" == "4" ]; then
    pkg update
    pkg install wazuh-agent-4.9.2 
    cp /etc/localtime /var/ossec/etc
    echo "Edit the var/ossec/etc/ossec.conf manually."
    echo "Edit /etc/rc.conf, adding: sysrc wazuh_agent_enable="YES""
    echo "Run: service wazuh-agent onestart"
fi

sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

# All additional configs for the agent are below:
# Adds port + inventory + SCA
sed -i.bak 's|<interval>1h</interval>|<interval>10min</interval>|g' /var/ossec/etc/ossec.conf
sed -i.bak 's|<ports all="no">yes</ports>|<ports all="yes">yes</ports>|g' /var/ossec/etc/ossec.conf
sed -i.bak '/<!-- Log analysis -->/a \\n  <localfile>\n    <log_format>audit</log_format>\n    <location>/var/log/audit/audit.log</location>\n  </localfile>' /var/ossec/etc/ossec.conf
sed -i.bak 's|<interval>12h</interval>|<interval>1h</interval>|g' /var/ossec/etc/ossec.conf

# Adds realtime FIM for following files
bash -c 'cat <<EOF | sed "/<!-- Directories to check  (perform all possible verifications) -->/r /dev/stdin" /var/ossec/etc/ossec.conf
<ignore>/root/.bash_history</ignore>
<directories realtime="yes">/etc/update-motd.d/</directories>
<directories realtime="yes">/etc/motd</directories>
<directories realtime="yes">/etc/sudoers</directories>
<directories realtime="yes">/etc/ssh/sshd_config</directories>
<directories realtime="yes">/etc/sudoers.d</directories>
<directories realtime="yes">/etc/sudoers</directories>
<directories realtime="yes">/etc/bash/bashrc</directories>
<directories realtime="yes">/var/ossec/etc/ossec.conf</directories>
<directories realtime="yes">/var/spool/cron/</directories>
<directories realtime="yes">/etc/security/</directories>
<directories realtime="yes">/etc/hosts.allow</directories>
<directories realtime="yes">/home/*/.ssh/authorized_keys</directories>
<directories realtime="yes">/home/*/.bashrc</directories>
<directories realtime="yes">/etc/group</directories>
<directories realtime="yes">/etc/shadow</directories>
<directories realtime="yes">/etc/passwd</directories>
<directories realtime="yes" check_all="yes" restrict=".sh$">/home</directories>

EOF'

# Adds active response alerts against new user+group creations

#bash -c 'cat <<EOF | sed "</active-response>/r /dev/stdin" /var/ossec/etc/ossec.conf > /var/ossec/etc/ossec.conf.new
#<active-response>
#  <command>user-creation-alert</command>
#  <location>local</location>
#  <rules_id>5902</rules_id>
#</active-response>

#EOF'

#################################################################
# ADD PORT MONITORING TO THE rules.xml FILE HERE
#################################################################

# Adds proper custom active response script
##touch /var/ossec/active-response/bin/user-creation-alert
#cat << EOF >> /var/ossec/active-response/bin/user-creation-alert
##!/bin/bash
#wall "WAZUH WARNING: A new user has been added to this system"
#EOF
#sudo chmod 750 /var/ossec/active-response/bin/user-creation-alert
#sudo chown root:wazuh /var/ossec/active-response/bin/user-creation-alert

# Adds auditd logging + alerts
######## THIS PART NOT DONE YET ####################################################################
#<localfile>
#    <location>/var/log/audit/audit.log</location>
#    <log_format>audit</log_format>
#</localfile>
######## THIS PART NOT DONE YET ###################################################################

#sudo mv /var/ossec/etc/ossec.conf.new /var/ossec/etc/ossec.conf
sudo systemctl restart wazuh-agent