#!/bin/sh

set -e
STAGE_DIR="/Library/pam_localauth"

wrong_dir() {
    WHERE="$0"
    echo "Please change to the directory this script is in before running it."
    echo "    cd $(dirname ${WHERE})"
    exit 1
}

module_not_functioning() {
    echo "The LocalAuthentication module does not seem to be working properly."
    echo "Make sure that 1) the Watch is in range, and 2) you approved the permission prompt."
    echo "Otherwise, please file an issue."
    exit 1
}

test -f "./libpam_localauth.dylib" || wrong_dir
test -f "./test_policy" || wrong_dir
test -f "./PAMTester" || wrong_dir

echo "[1/4] Installing PAM module"
echo "You may be asked for your password."
set -x
sudo mkdir -p "${STAGE_DIR}"
sudo cp -i "./libpam_localauth.dylib" "${STAGE_DIR}"
sudo chown root:wheel "${STAGE_DIR}/libpam_localauth.dylib"
sudo chmod 644 "${STAGE_DIR}/libpam_localauth.dylib"
set +x

echo "[2/4] Testing PAM module"
sudo cp -i "./test_policy" "/etc/pam.d/test_localauth"
sudo chown root:wheel "/etc/pam.d/test_localauth"
echo "You should be prompted for approval on Apple Watch..."
./PAMTester test_localauth || module_not_functioning
sudo rm -f "/etc/pam.d/test_localauth"

insert_lib() {
    local DONE=0
    while IFS= read line; do
        # On the first non-comment line we insert our module definition
        if [ ${DONE} -ne 1 ] && [ ! $(cut -c1 <<< "${line}") == "#" ]; then
            printf "auth\tsufficient\t%s\n" "${STAGE_DIR}/libpam_localauth.dylib"
            DONE=1
        fi
        printf "%s\n" "$line"
    done
}

echo "[3/4] Modifying the sudo PAM policy"
# We create this as root so other users can't overwrite it while we're modifying the policy.
TMPNAM=$(sudo mktemp "/tmp/install.XXXXXXXXXXXX")
# Make sure it's not already installed...
if ! >>/dev/null grep -- "${STAGE_DIR}/libpam_localauth.dylib" "/etc/pam.d/sudo"; then
    # Edit policy into temp file
    </etc/pam.d/sudo insert_lib | sudo sh -c ">>${TMPNAM} cat"
    sudo chmod 644 "${TMPNAM}"
    # Copy into place
    sudo cp -i "${TMPNAM}" "/etc/pam.d/sudo"
fi

echo "[4/4] Install complete; finishing up"
# Clear session so user will be prompted on their next command.
sudo -k
