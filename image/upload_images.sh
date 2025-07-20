#!/bin/bash

set -e

# === 1. 이미지 정보 ===
UBUNTU_IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
UBUNTU_IMG_NAME="ubuntu-22.04.img"
UBUNTU_IMAGE_NAME="ubuntu-22.04"

NAVIX_IMG_URL="https://dlnavix.navercorp.com/cloud-images/Navix-GenericCloud-latest.x86_64.qcow2"
NAVIX_IMG_NAME="navix-9.6.qcow2"
NAVIX_IMAGE_NAME="navix-9.6"

# === 2. Ubuntu 이미지 다운로드 ===
if [ -f "$UBUNTU_IMG_NAME" ]; then
    echo "[✓] Ubuntu 이미지 파일이 이미 존재합니다: $UBUNTU_IMG_NAME (스킵)"
else
    echo "[↓] Ubuntu 이미지를 다운로드합니다..."
    wget -O "$UBUNTU_IMG_NAME" "$UBUNTU_IMG_URL"
fi

# === 3. Ubuntu 이미지 OpenStack 등록 ===
if openstack image list -f value -c Name | grep -q "^${UBUNTU_IMAGE_NAME}$"; then
    echo "[✓] OpenStack에 Ubuntu 이미지가 이미 등록되어 있습니다: $UBUNTU_IMAGE_NAME (스킵)"
else
    echo "[+] OpenStack에 Ubuntu 이미지를 등록합니다..."
    openstack image create "$UBUNTU_IMAGE_NAME" \
        --file "$UBUNTU_IMG_NAME" \
        --disk-format qcow2 \
        --container-format bare \
        --public
fi

# === 4. Navix 이미지 다운로드 ===
if [ -f "$NAVIX_IMG_NAME" ]; then
    echo "[✓] Navix 이미지 파일이 이미 존재합니다: $NAVIX_IMG_NAME (스킵)"
else
    echo "[↓] Navix 이미지를 다운로드합니다..."
    wget -O "$NAVIX_IMG_NAME" "$NAVIX_IMG_URL"
fi

# === 5. Navix 이미지 OpenStack 등록 ===
if openstack image list -f value -c Name | grep -q "^${NAVIX_IMAGE_NAME}$"; then
    echo "[✓] OpenStack에 Navix 이미지가 이미 등록되어 있습니다: $NAVIX_IMAGE_NAME (스킵)"
else
    echo "[+] OpenStack에 Navix 이미지를 등록합니다..."
    openstack image create "$NAVIX_IMAGE_NAME" \
        --file "$NAVIX_IMG_NAME" \
        --disk-format qcow2 \
        --container-format bare \
        --public
fi

echo "[✔] 모든 작업이 완료되었습니다."
