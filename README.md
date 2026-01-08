# Module 6 - Artifact Repository Manager with Nexus

## Project: Run Nexus on Droplet and Publish Artifact to Nexus

This project guides you through the process of setting up an artifact repository. You will learn how to install, secure, and configure **Sonatype Nexus Repository Manager** on a cloud server following best practices.

### Technologies Used

* **Nexus Repository Manager**
* **DigitalOcean** (Cloud Infrastructure)
* **Linux** (Ubuntu Server)
* **Java** (OpenJDK 17)
* **Gradle** (Gradle 9.2.1)
* **Maven** (Apache Maven 3.9.12)

### Project Description

* Install and configure Nexus from scratch on a cloud server
* Create a new user on Nexus with relevant permissions
* Java Gradle Project: Build a Jar and upload it to Nexus
* Java Maven Project: Build a Jar and upload it to Nexus

### Prerequisites

* A DigitalOcean Droplet (Ubuntu 22.04 or 24.04 recommended). [Create a Droplet](https://github.com/ana-os-mo/digital-ocean-server/blob/main/README.md#step-1-create-a-digitalocean-droplet) and [Configure the Firewall](https://github.com/ana-os-mo/digital-ocean-server/blob/main/README.md#step-2-configure-the-initial-firewall)
* SSH access via a non-root user with `sudo` privileges. [Configure the User](https://github.com/ana-os-mo/digital-ocean-server/blob/main/README.md#step-3-connect-and-configure-a-secure-admin-user)

**Droplet's Recommended Plan:** Nexus is a resource-intensive Java application. To avoid performance issues, use the following specifications:

* 8 GB RAM / 4 vCPUs
* 160 GB SSD
* 5 TB Transfer

---

Nexus Artifact Repository is a tool used to store, manage, and share build artifacts like libraries, packages, and container images. Teams publish and retrieve them from Nexus. It also helps control versions, enforce policies, and maintain a single trusted source of artifacts across development, CI/CD pipelines, and production.

<details>
<summary><strong>Step 1: Install Java and Download Nexus</strong></summary>

From your local terminal, access the server with your admin user via SSH to begin with the installation.

1. **Install Java on the server:** Install `OpenJDK 17` (required for Nexus 3.72.0-04) if not installed yet. Use `java -version` to verify the installation.

    ```bash
    sudo apt update
    sudo apt install openjdk-17-jre-headless -y
    ```

2. **Download Nexus:** Navigate to the `/opt` directory and download Nexus `3.72.0-04`.

    ```bash
    cd /opt
    sudo wget https://download.sonatype.com/nexus/3/nexus-3.72.0-04-unix.tar.gz
    ```

3. **Unzip**: Extract the archive to generate the two core directories.

    ```bash
    sudo tar -zxvf nexus-3.72.0-04-unix.tar.gz
    ```

    * **Nexus Folder (`/opt/nexus-3.72.0-04`):** The **Installation Directory**. It contains the application binaries and runtime code. This should remain read-only for the service user to prevent unauthorized modifications to the software.
    * **Sonatype Folder (`/opt/sonatype-work`):** The **Data Directory**. This contains your repositories, blob stores, databases, and logs. This directory must be writable by the Nexus user and is the most important folder to include in your backup strategy.

> [!TIP]
> **Using Other Versions:**
> While this guide uses version `3.72.0-04`, you can find alternative releases on the [Sonatype Download Archives](https://help.sonatype.com/en/download-archives---repository-manager-3.html). However, you must verify the [Nexus System Requirements](https://help.sonatype.com/en/sonatype-nexus-repository-system-requirements.html) as newer versions (3.87+) typically require **Java 21**, while older versions may require **Java 8 or 11** and may have different hardware needs.

</details>

---

<details>
<summary><strong>Step 2: Create a Dedicated Service Account to Run Nexus</strong></summary>

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

2. **Run the script:** On the **server**, navigate to your home directory and run the script with the version as a parameter.

    ```bash
    # Make the script executable
    sudo chmod +x setup_nexus_env.sh

    # Run the script
    sudo ./setup_nexus_env.sh "3.72.0-04"
    ```

</details>

---

<details>
<summary><strong>Step 3: Run Nexus</strong></summary>

You can run Nexus manually or configure it as a system service. Using **Systemd** is highly recommended for production to ensure the application restarts on failure and correctly manages file handle limits.

### Option A: Manual Execution (For Testing)

If you wish to run the application manually:

```bash
# Switch to nexus user
sudo su - nexus

# Start the service
/opt/nexus/bin/nexus start
```

**Note:** To stop it manually, use `/opt/nexus/bin/nexus stop`.

### Option B: Systemd Service (Recommended)

With your admin user:

1. **Create the service file:**

    ```bash
    sudo vim /etc/systemd/system/nexus.service
    ```

2. **Paste the following configuration:** You can see the explanation for each line in the `scripts/system-service.ini` file provided in this project.

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

4. **Check the Service Status:**

    ```bash
    sudo systemctl status nexus
    ```

    * **Note:** Nexus takes 1-2 minutes to fully boot up. You can monitor the progress by following the logs:

    ```bash
    sudo tail -f /opt/sonatype-work/nexus3/log/nexus.log
    ```

    Wait until you see the message: `Started Sonatype Nexus OSS 3.72.0-04`.

</details>

---

<details>
<summary><strong>Step 4: Update Firewall and Initial Login</strong></summary>

Verify the application is running on port `8081` (Nexus default).

```bash
# Get the process
ps aux | grep nexus

# Get the port knowing the process (:::8081)
netstat -lnpt
```

1. **Configure DigitalOcean Firewall**:

    Go to **DigitalOcean Dashboard > Networking > Firewalls**. Edit your firewall and add a new **Inbound Rule**:

    | Type | Protocol | Port Range | Sources | Purpose |
    | --- | --- | --- | --- | --- |
    | **Custom** | TCP | 8081 | `All IPv4` `All IPv6` | Allows the public to access your app. |

2. **Verify Access**: Open your browser and navigate to `http://{droplet-ip}:8081`.

3. **Initial Admin Password**: To log in for the first time as the Nexus `admin` user, you need to retrieve the auto-generated temporary password:

    ```bash
    sudo cat /opt/sonatype-work/nexus3/admin.password
    ```

    **Credentials:**
      * **Username:** `admin`
      * **Password:** (from the command above)

    Then:
      1. Navigate to `http://{droplet-ip}:8081` and click **Sign in**
      2. Enter the credentials
      3. You will be prompted to create a new permanent password for the admin user
      4. Enable anonymous access

</details>

---

<details>
<summary><strong>Step 5: Create a User in Nexus</strong></summary>

We will use the default `maven-snapshots` hosted repository in Nexus.

For security best practices, we should not share admin credentials. Instead, create a dedicated user with limited permissions to upload and download artifacts from the repository.

**Prerequisites:** You must be logged in as the admin user.

1. **Create a Role:** Roles define which repositories and operations a user can access. Create a role with appropriate permissions for uploading artifacts.

    * Navigate to **Settings (Gear Icon) > Security > Roles**.
    * Click **Create Role** and select **Nexus role** as the type.
    * Assign a `Role ID` and a `Role Name`.
    * Click **Modify Applied Privileges** and search for `nx-repository-view-maven2-maven-snapshots-*` (this gives full access to the snapshots repo).
    * Click **Save** at the bottom of the page.

    <p align="center">
      <img src="assets/create-nexus-role.png" alt="vm-selection" width="500"/>
    </p>

2. **Create a Nexus User:** Create a new user and assign it the role you created above to access the snapshots repository.

    * Go to **Settings > Security > Users**.
    * Click **Create local user**.
    * Fill the required fields and add the role.
    * Click **Create local user**.

    <p align="center">
      <img src="assets/create-nexus-user.png" alt="vm-selection" width="500"/>
    </p>

</details>

---

<details>
<summary><strong>Step 6: Upload JAR File to Nexus</strong></summary>

Now we will configure our Java projects to talk to Nexus. We will look at two different build tools: **Gradle** and **Maven**.

### Gradle Project

Use your terminal to open the `java-gradle-app` project in your local machine.

1. **Configure `build.gradle`:**

    We need to add the `maven-publish` plugin. This plugin adds the necessary tasks to the Gradle build (like `publish`) to generate the POM file and upload the artifacts.

    ```groovy
    plugins {
      ...
      id 'maven-publish' // Required to publish artifacts to a remote repo
      ...
    }

    ...

    group = 'com.example'
    version = '1.0-SNAPSHOT'

    publishing {
      // Define WHAT to publish
      publications {
        create('maven', MavenPublication) {
          artifact tasks.named('bootJar')
        }
      }

      // Define WHERE to publish
      repositories {
        maven {
          name = 'nexus'
          // The URL to your specific repository on the server
          url = uri("http://{your_nexus_ip}:{your-nexus-port}/path-to/your-repository/")
          // Since we haven't set up SSL (HTTPS), Gradle will block
          // the connection by default for security. We must explicitly allow HTTP.
          allowInsecureProtocol = true
          credentials {
            username = project.findProperty('nexusUsername')
            password = project.findProperty('nexusPassword')
          }
        }
      }
    }

    ...
    ```

    You can get the Nexus URL from the repository.

    <p align="center">
      <img src="assets/maven-snapshots-repository.png" alt="vm-selection" width="600"/>
    </p>

2. **Configure Credentials:**

    You should **never** hardcode passwords inside `build.gradle`, as that file is committed to Git. Instead, we use `gradle.properties` and exclude it from version control, or use environment variables.

    Create or edit `gradle.properties` in the project root and use the credentials for the user we created in Step 5.

    ```properties
    nexusUsername = replace_with_your_nexus_username
    nexusPassword = replace_with_your_nexus_password
    ```

3. **Build and Publish:**

    Run the following commands in your terminal:

    ```bash
    # 1. Compile the code and package the JAR
    gradle build

    # 2. Upload the JAR and generated POM to Nexus
    gradle publish
    ```

4. **Verify:**

    Go to Nexus **Browse server contents > Browse** and open the `maven-snapshots` reposiry. You should see your artifact structure created automatically.

    <p align="center">
      <img src="assets/uploaded-gradle-snapshot.png" alt="vm-selection" width="600"/>
    </p>

### Maven Project

Use your terminal to open the `java-maven-app` project in your local machine.

Maven handles publication differently. It separates **Project Information** (stored in `pom.xml`) from **User Credentials** (stored in `settings.xml`).

1. **Configure `pom.xml`**

    In this file we should define what we are building, add the `maven-deploy-plugin` to handle connection to Nexus, and tell Maven where the Nexus server is located.

    ```xml
    <project ...>
        ...
        <groupId>com.example</groupId>
        <artifactId>my-maven-app</artifactId>
        <version>1.0-SNAPSHOT</version>

        <build>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-deploy-plugin</artifactId>
                    <version>3.1.4</version>
                </plugin>
                ...
            </plugins>
        </build>

        <distributionManagement>
            <snapshotRepository>
                <id>nexus-snapshots</id>
                <url>http://{your_nexus_ip}:{your-nexus-port}/path-to/your-repository</url>
            </snapshotRepository>
        </distributionManagement>
        ...
    </project>
    ```

2. **Configure Credentials:**

    Maven looks for credentials in your local home directory (`~/.m2/settings.xml`). This file is global for your user. The `.m2` directory is typically created automatically the first time a Maven build command is executed.

    ```bash
    vim ~/.m2/settings.xml
    ```

    Add the `<server>` configuration to the file. **Important:** The `<id>` here must match the `<id>` you put in the `pom.xml` exactly.

    ```xml
    <settings>
      <servers>
        <server>
          <id>nexus-snapshots</id>
          <username>replace_with_your_nexus_username</username>
          <password>replace_with_your_nexus_password</password>
        </server>
      </servers>
    </settings>
    ```

3. **Deploy:**

    In Maven, the `deploy` lifecycle phase handles the upload.

    ```bash
    # 'deploy' runs all previous steps (compile, test, package) and then uploads
    mvn deploy
    ```

    <p align="center">
      <img src="assets/uploaded-maven-snapshot.png" alt="vm-selection" width="600"/>
    </p>

</details>
