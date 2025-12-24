# Module 6 - Artifact Repository Manager with Nexus

## Project: Run Nexus on Droplet and Publish Artifact to Nexus

This project guides you through the process of setting up an artifact repository. You will learn how to install, secure, and configure **Sonatype Nexus Repository Manager** on a cloud server following best practices.

### Technologies Used

* **Nexus Repository Manager**
* **DigitalOcean** (Cloud Infrastructure)
* **Linux** (Ubuntu Server)
* **Java** (OpenJDK 17)
* **Gradle & Maven** (Build Tools)

### Project Description

* Install and configure Nexus from scratch on a cloud server
* Create a new user on Nexus with relevant permissions
* Java Gradle Project: Build a Jar and upload it to Nexus
* Java Maven Project: Build a Jar and upload it to Nexus

### Prerequisites

* A DigitalOcean Droplet (Ubuntu 22.04 or 24.04 recommended).
* SSH access via a non-root user with `sudo` privileges.

**Droplet's Recommended Plan:** Nexus is a resource-intensive Java application. To avoid performance issues, use the following specifications:

* 8 GB RAM / 4 vCPUs
* 160 GB SSD
* 5 TB Transfer

You can see how to create and configure the Droplet in this [README](https://github.com/ana-os-mo/digital-ocean-server/blob/main/README.md) file.

---

Nexus Artifact Repository is a tool used to store, manage, and share build artifacts like libraries, packages, and container images. Teams publish and retrieve them from Nexus. It also helps control versions, enforce policies, and maintain a single trusted source of artifacts across development, CI/CD pipelines, and production.

### Step 1: Install Java and Download Nexus

From your local terminal, access the server with your admin user via SSH to begin with the installation.

1. **Install Java on the server:** Install `OpenJDK 17` (required for Nexus 3.72.0-04) if not installed yet. Use `java -version` to verify the installation.

```bash
sudo apt update
sudo apt install openjdk-17-jre-headless -y
```

2. **Download Nexus:** Navigate to the `/opt` directory and download Nexus `3.72.0-04`.

```bash
cd /opt
wget https://download.sonatype.com/nexus/3/nexus-3.72.0-04-unix.tar.gz
```

3. **Unzip**: Extract the archive to generate the two core directories.

```bash
sudo tar -zxvf nexus-3.72.0-04-unix.tar.gz
```

* **Nexus Folder (`/opt/nexus-3.72.0-04`):** The **Installation Directory**. It contains the application binaries and runtime code. This should remain read-only for the service user to prevent unauthorized modifications to the software.
* **Sonatype Folder (`/opt/sonatype-work`):** The **Data Directory**. This contains your repositories, blob stores, databases, and logs. This directory must be writable by the Nexus user and is the most important folder to include in your backup strategy.

> [!TIP]
> **Using Other Versions:**
> While this guide focuses on version `3.72.0-04`, you can find alternative releases on the [Sonatype Download Archives](https://help.sonatype.com/en/download-archives---repository-manager-3.html). However, you must verify the [Nexus System Requirements](https://help.sonatype.com/en/sonatype-nexus-repository-system-requirements.html) as newer versions (3.87+) typically require **Java 21**, while older versions may require **Java 8 or 11** and may have different hardware needs.

---

### Step 2: Create a Dedicated Service Account to Run Nexus

Running Nexus as `root` is a significant security risk. We will create a dedicated system user and apply the **Principle of Least Privilege**. You can do it yourself or use the provided script.

**What the script does:**

* **Creates a System User**: Sets up a restricted `nexus` user with a valid shell but no password login.
* **Initializes Profile Workspace**: Creates `/var/lib/nexus` as a clean home directory for Java preferences.
* **Version Management**: Creates a symbolic link at `/opt/nexus` for easier future upgrades.
* **Sets Strict Permissions**: Grants the `nexus` user ownership of the data and profile folders while keeping binaries owned by `root`.

***Execution***

1. **Transfer the script**: From your **local machine**, copy the `setup-nexus-env.sh` script to your admin user's home directory in the server.

```bash
# Secure copy
scp ./scripts/setup_nexus_env.sh admin@{droplet-ip}:/home/admin/
```

2. **Run the environment script:** On the **server**, navigate to your home directory and run the script with the version as a parameter.

```bash
# Make the excript executable
sudo chmod +x setup_nexus_env.sh

# Run the script
sudo ./setup_nexus_env.sh 3.72.0-04
```

---

### Step 3: Run Nexus

You can run Nexus manually or configure it as a system service. Using **Systemd** is highly recommended for production to ensure the application restarts on failure and correctly manages file handle limits.

#### Option A: Manual Execution (For Testing)

If you wish to run the application manually:

```bash
# Switch to nexus user
sudo su - nexus

# Start the service
/opt/nexus/bin/nexus start
```

**Note:** To stop it manually, use `/opt/nexus/bin/nexus stop`.

#### Option B: Systemd Service (Recommended)

1. **Create the service file:**

```bash
sudo vim /etc/systemd/system/nexus.service
```

2. **Paste the following configuration:** You can see the explanation for each line in the `scripts/

```ini
[Unit]
Description=Nexus Repository Service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
User=nexus
WorkingDirectory=/var/lib/nexus
Restart=on-abort
TimeoutSec=600

[Install]
WantedBy=multi-user.target
```

3. **Start and Enable**: Activate the service with the following commands

```bash
sudo systemctl daemon-reload
sudo systemctl enable nexus
sudo systemctl start nexus
```

4. **Check the Service Status:** You can use any of the following commands

```bash
sudo systemctl status nexus

tail -f /opt/nexus3/log/nexus.log
```

* With the status command, if the service is running you will see something similar to `active (running)` in the output.
* The tail command verifies that the service has been started successfully. If successful, you should see a message notifying you that it is listening for HTTP.

---

### Step 4: Update the Firewall and Initial Login

Now that the application environment is set up, verify it is running on port `8081` (Nexus default).

```bash
# Get the process
ps aux | grep nexus

# Get the port knowing the process (:::8081)
netstat -lnpt
```

1. **Configure DigitalOcean Firewall**:

Return to the **DigitalOcean Dashboard > Networking > Firewalls**. Then, edit your existing firewall and add a new **Inbound Rule**:

| Type | Protocol | Port Range | Sources | Purpose |
| --- | --- | --- | --- | --- |
| **Custom** | TCP | 8081 | `All IPv4` `All IPv6` | Allows the public to access your app. |

2. **Verify Access**: Open your browser and navigate to `http://{droplet-ip}:8081`.

3. **Initial Admin Password**: To log in for the first time as the Nexus `admin` user, retrieve the generated password from the server:

```bash
sudo cat /opt/sonatype-work/nexus3/admin.password
```
