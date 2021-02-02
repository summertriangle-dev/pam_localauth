#!/bin/sh
set -e
STAGE_DIR="/Library/pam_localauth"

failed_to_unpatch() {
    echo "The LocalAuthentication module could not be removed from the sudo PAM policy."
    echo "It is unsafe to continue with the removal, so I am stopping here."
    echo "Please file an issue."
    exit 1
}

echo "[1/3] Modifying the sudo PAM policy"
echo "You will be asked to approve the following commands..."
# We create this as root so other users can't overwrite it while we're modifying the policy.
TMPNAM=$(sudo mktemp "/tmp/install.XXXXXXXXXXXX")
# Make sure it's not already installed...
grep -v -- "${STAGE_DIR}/libpam_localauth.dylib" "/etc/pam.d/sudo" | sudo sh -c ">>${TMPNAM} cat"
sudo chmod 644 "${TMPNAM}"
# Copy into place
sudo cp -i "${TMPNAM}" "/etc/pam.d/sudo"

grep -- "${STAGE_DIR}/libpam_localauth.dylib" "/etc/pam.d/sudo" && failed_to_unpatch

echo "[2/3] Removing old files"
echo "Type 'y' to confirm each step."
sudo rm -ri "${STAGE_DIR}"

echo "[3/3] Done; finishing up"
sudo -k
