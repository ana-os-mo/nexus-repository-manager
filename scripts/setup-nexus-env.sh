#! /bin/bash

# This script configures a dedicated service environment for Nexus Repository Manager.
# It creates a restricted system user, manages a three-tier directory structure,
# and applies strict security permissions (Least Privilege).
# ---
# NOTE: This script must be run with 'sudo'.
# ---

# Usage: ./setup-nexus-env.sh <nexus_version>

NEXUS_VERSION=$1
NEXUS_USER="nexus"
NEXUS_USER_HOME="/var/lib/nexus"
NEXUS_APP="/opt/nexus"
NEXUS_DATA="/opt/sonatype-work"

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

echo "Setting up service environment for Nexus $NEXUS_VERSION..."

# 1. Create User Profile Directory
# This serves as the workspace for the nexus user's system-level profile.
mkdir -p "$NEXUS_USER_HOME"

# 2. Create Service User
# Check if the user already exists to make the script idempotent.
if id "$NEXUS_USER" &>/dev/null; then
    echo "User already exists."
else
    # useradd: Creates a new user account.
    # --system: Creates a 'system user' (usually UID < 1000). System users don't expire.
    # --no-create-home: Prevents the creation of a standard /home/nexus folder.
    # --home-dir: Explicitly sets the user's home to our profile directory.
    # --shell /bin/bash: Required because the Nexus startup script uses 'su' to switch users.
    useradd --system \
            --no-create-home \
            --home-dir "$NEXUS_USER_HOME" \
            --shell /bin/bash \
            --comment "Nexus Repository Service Account" \
            "$NEXUS_USER"

    # passwd -l: Locks the account password.
    # This prevents anyone from logging into this account directly via password.
    passwd -l "$NEXUS_USER"
    echo "System user '$NEXUS_USER' created."
fi

# 3. Setup Application Symlink
# ln -sf: Creates a symbolic link.
# -f: Force (overwrites the link if it already exists, useful for upgrades).
# This points the generic /opt/nexus path to the specific versioned folder.
ln -sf "/opt/nexus-${NEXUS_VERSION}" "$NEXUS_APP"

# 4. Configure Nexus Run User
# This file (nexus.rc) is read by the Nexus binary to determine which user should own the process.
echo "run_as_user=\"$NEXUS_USER\"" > "$NEXUS_APP/bin/nexus.rc"

# 5. Apply Permissions (Principle of Least Privilege)
echo "Applying permissions..."

# A. Application Files (Immutable)
# chown -R root:"$NEXUS_USER": Owner is root, group is nexus.
# chmod -R 750:
#   7 (rwx) for Root: Full control to update or delete.
#   5 (r-x) for Nexus Group: Permission to read and execute the software.
chown -R root:"$NEXUS_USER" "/opt/nexus-${NEXUS_VERSION}"
chown -h root:"$NEXUS_USER" "$NEXUS_APP"
chmod -R 750 "/opt/nexus-${NEXUS_VERSION}"

# B. Data Directory (Mutable)
# chown -R "$NEXUS_USER":"$NEXUS_USER": The service user owns these files entirely.
# chmod -R 700: Only the nexus user can read/write here.
chown -R "$NEXUS_USER":"$NEXUS_USER" "$NEXUS_DATA"
chmod -R 700 "$NEXUS_DATA"

# C. User Profile Workspace
# This ensures any hidden Java preferences or shell logs are kept private to the nexus user.
chown -R "$NEXUS_USER":"$NEXUS_USER" "$NEXUS_USER_HOME"
chmod -R 700 "$NEXUS_USER_HOME"

echo "Environment setup for Nexus $NEXUS_VERSION successful."
