#!/bin/bash
# enable-browser-sandbox.sh
#
# Ubuntu 24.04 restricts unprivileged user namespaces with AppArmor
# (kernel.apparmor_restrict_unprivileged_userns=1). Chrome's sandbox needs
# them, so the Chrome that Playwright downloads aborts at startup with
# "No usable sandbox!" and the OpenClaw browser tool cannot launch.
#
# This installs a narrow AppArmor profile that lets ONLY the Playwright-managed
# Chrome binaries create user namespaces. The sandbox stays ON, and the global
# restriction stays in place for everything else.
#
# Usage:   sudo ./enable-browser-sandbox.sh          install and verify
#          sudo ./enable-browser-sandbox.sh --undo   remove the profile
# Verify:  openclaw browser start && openclaw browser status
#
# Found on aletheia-core 2026-11-07 (Ubuntu 24.04.4, kernel 6.8.0-147).

PROFILE_NAME="playwright-chromium"
PROFILE_FILE="/etc/apparmor.d/${PROFILE_NAME}"
SETUP_FILE="/etc/exocortical-browser-sandbox.done"
TARGET_USER="${SUDO_USER:-$USER}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0 $*"
  exit 1
fi

if [ "$1" = "--undo" ]; then
  [ -f "$PROFILE_FILE" ] && apparmor_parser -R "$PROFILE_FILE"
  rm -f "$PROFILE_FILE" "$SETUP_FILE"
  echo "Removed ${PROFILE_NAME}. Chrome's sandbox is blocked again on this machine."
  exit 0
fi

if [ -f "$SETUP_FILE" ] && [ -f "$PROFILE_FILE" ]; then
  echo "Already set up ($SETUP_FILE). Use --undo to remove."
  exit 0
fi

if ! command -v apparmor_parser >/dev/null 2>&1; then
  echo "apparmor_parser not found. Nothing to do on a machine without AppArmor."
  exit 1
fi

RESTRICT=$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)
echo "apparmor_restrict_unprivileged_userns=${RESTRICT:-absent}"
if [ "$RESTRICT" != "1" ]; then
  echo "The userns restriction is not active here, so this is probably not your problem."
  echo "Nothing installed."
  exit 1
fi

# Use the abi line only where the abi file exists (24.04 ships abi/4.0)
ABI_LINE=""
[ -f /etc/apparmor.d/abi/4.0 ] && ABI_LINE="abi <abi/4.0>,"

cat > "$PROFILE_FILE" <<EOF
${ABI_LINE}
include <tunables/global>

# Playwright-managed Chrome for Testing (any user's cache; any version).
profile ${PROFILE_NAME} /home/*/.cache/ms-playwright/chromium-*/chrome-linux*/chrome flags=(unconfined) {
  userns,

  # Site-local overrides
  include if exists <local/${PROFILE_NAME}>
}
EOF

apparmor_parser -r "$PROFILE_FILE" || { echo "Profile failed to load; removing it."; rm -f "$PROFILE_FILE"; exit 1; }
echo "Loaded $PROFILE_FILE"

# Verify as the invoking user, WITH the sandbox on (no --no-sandbox)
CHROME=$(ls -d /home/"$TARGET_USER"/.cache/ms-playwright/chromium-*/chrome-linux*/chrome 2>/dev/null | tail -1)
if [ -z "$CHROME" ]; then
  echo "No Playwright Chrome found for $TARGET_USER; profile installed but not verified."
else
  OUT=$(sudo -u "$TARGET_USER" timeout 30 "$CHROME" --headless=new --disable-gpu --dump-dom about:blank 2>&1)
  if echo "$OUT" | grep -q "<html"; then
    echo "Verified: Chrome launches with its sandbox enabled ($CHROME)"
  else
    echo "Profile loaded but Chrome still failed:"
    echo "$OUT" | head -5
    exit 1
  fi
fi

echo "Done" | tee "$SETUP_FILE"
echo "Next: openclaw browser start"
