#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Simple autoinstall for OSCam_r11720_emu_smod
# Usage:
#   sudo ./install.sh [--with-ffdecsa] [--with-patch-apply] [--no-systemd]

WITH_FFDECSA=0
APPLY_PATCHES=0
SETUP_SYSTEMD=1

for arg in "$@"; do
  case "$arg" in
    --with-ffdecsa) WITH_FFDECSA=1 ;;
    --with-patch-apply) APPLY_PATCHES=1 ;;
    --no-systemd) SETUP_SYSTEMD=0 ;;
    *) echo "Unknown option: $arg"; exit 2 ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit 1; }

# helper: package manager detection
if command -v apt-get >/dev/null 2>&1; then
  PKG_MGR="apt"
elif command -v dnf >/dev/null 2>&1; then
  PKG_MGR="dnf"
elif command -v yum >/dev/null 2>&1; then
  PKG_MGR="yum"
else
  die "No supported package manager found (apt/dnf/yum required)"
fi

echo "Detected package manager: $PKG_MGR"

install_packages() {
  if [ "$PKG_MGR" = "apt" ]; then
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
      build-essential git cmake pkg-config libssl-dev \
      libpcsclite-dev libusb-1.0-0-dev autoconf automake libtool
  else
    # CentOS / RHEL
    sudo $PKG_MGR -y install epel-release || true
    sudo $PKG_MGR -y install gcc gcc-c++ make git cmake pkgconfig openssl-devel \
      pcsc-lite-devel libusb1-devel autoconf automake libtool
  fi
}

echo "[1/8] Installing system packages (if missing)"
install_packages

echo "[2/8] Creating directories"
sudo mkdir -p /usr/local/etc/oscam2
sudo mkdir -p /usr/local/bin

# 3: restore binary if present in repo/bin
if [ -f "./bin/oscam2" ]; then
  echo "[3/8] Installing provided oscam2 binary to /usr/local/bin/oscam2"
  sudo cp ./bin/oscam2 /usr/local/bin/oscam2
  sudo chmod +x /usr/local/bin/oscam2
else
  echo "[3/8] No bin/oscam2 found in repo — skipping binary restore (you can add it to bin/oscam2)"
fi

echo "[4/8] Installing configuration files"
if [ -d "./configs" ] && [ "$(ls -A ./configs)" ]; then
  sudo cp -r ./configs/* /usr/local/etc/oscam2/
  sudo chown -R root:root /usr/local/etc/oscam2
else
  echo "  -> No configs/ present. Add your oscam.conf etc. to ./configs/"
fi

# apply patches (if requested) - this tries to apply textual patches against /usr/local/src/oscam2 if present
if [ "$APPLY_PATCHES" -eq 1 ]; then
  echo "[5/8] Applying patches (patches/ directory)"
  if [ -d "./patches" ] && [ "$(ls -A ./patches)" ]; then
    cd /usr/local/src || sudo mkdir -p /usr/local/src && cd /usr/local/src
    if [ ! -d ./oscam2 ]; then
      echo "  -> /usr/local/src/oscam2 not found. Clone first if you want to build from source."
    else
      for p in "$OLDPWD"/patches/*; do
        [ -f "$p" ] || continue
        echo "  -> Applying patch: $(basename "$p")"
        sudo patch -p1 -d ./oscam2 < "$p" || echo "     (patch may already applied or failed)"
      done
    fi
    cd "$OLDPWD"
  else
    echo "  -> No patches/ to apply."
  fi
fi

# Optional: build & install ffdecsa (if requested)
if [ "$WITH_FFDECSA" -eq 1 ]; then
  echo "[6/8] Building and installing FFDecsa (local build)"
  sudo mkdir -p /usr/local/src
  if [ ! -d /usr/local/src/ffdecsa ]; then
    sudo git clone https://github.com/bp0/ffdecsa.git /usr/local/src/ffdecsa || echo "git clone failed (check network)"
  fi
  cd /usr/local/src/ffdecsa
  sudo make -j"$(nproc)" || { echo "ffdecsa make failed"; exit 1; }
  sudo make install || { echo "ffdecsa make install failed"; exit 1; }
  cd -
fi

# systemd service with $OPTIONS support
if [ "$SETUP_SYSTEMD" -eq 1 ]; then
  echo "[7/8] Installing systemd service"
  sudo install -d /etc/systemd/system
  sudo cp ./service/oscam2.service /etc/systemd/system/oscam2.service || echo "service file not found in repo/service/"
  sudo systemctl daemon-reload
  sudo systemctl enable oscam2.service || echo "enable failed"
  sudo systemctl restart oscam2.service || echo "restart failed (check logs)"
fi

echo "[8/8] Done. Check service status with: sudo systemctl status oscam2"
echo "If WebIF not reachable, verify /usr/local/etc/oscam2/oscam.conf and ports."
echo ""
echo "To add options without editing service file use:"
echo "sudo systemctl edit oscam2.service"
echo "And add:"
echo "[Service]"
echo "Environment=\"OPTIONS=-b -r 2\""