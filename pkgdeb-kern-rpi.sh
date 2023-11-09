#!/usr/bin/bash
#
# @Pietro Sammarco | github.com/psammarco
#   
# USAGE:
#
# ./pkgdeb-kern-rpi.sh create PACKAGENAME
# ./pkgdeb-kern-rpi.sh clean PACKAGENAME
#
# Requirements: bash build-essential devscripts 
# Compiled kernel should reside at /usr/src/linux. 
# Run it as root!

ARCHITECTURE="aarch64"
WORKDIR="/opt/pkgbin"
SOURCE="/usr/src/linux"
KERNELNAME="6.1.58-rt16-v8"

function CREATE() {
    if [ ! -d "${WORKDIR}/${PACKAGENAME}/DEBIAN" ]; then
        mkdir -p "${WORKDIR}/${PACKAGENAME}/DEBIAN"
    else
        echo "A directory ${WORKDIR}/${PACKAGENAME} already exists!"
        echo "Use './pkgdeb-kern-rpi.sh clean' to remove it."
        exit 0
    fi

    echo "Creating package structure..."
    mkdir -p "${WORKDIR}/${PACKAGENAME}/DEBIAN/boot/firmware/overlays"
    cp "${SOURCE}/arch/arm64/boot/dts/broadcom/"*.dtb "${WORKDIR}/${PACKAGENAME}/DEBIAN/boot"
    cp "${SOURCE}/arch/arm64/boot/dts/overlays/"*.dtb* "${WORKDIR}/${PACKAGENAME}/DEBIAN/boot/firmware/overlays/"
    cp "${SOURCE}/arch/arm64/boot/dts/overlays/README" "${WORKDIR}/${PACKAGENAME}/DEBIAN/boot/firmware/overlays/"
    cp "${SOURCE}/arch/arm64/boot/Image" "${WORKDIR}/${PACKAGENAME}/DEBIAN/boot/$KERNELNAME.img"
    # To add initramfs cp later
    mkdir -p "${WORKDIR}/${PACKAGENAME}/DEBIAN/lib/modules"
    cp -a "/lib/modules/$KERNELNAME+" "${WORKDIR}/${PACKAGENAME}/DEBIAN/lib/modules"

    # preinstall script
    cd "${WORKDIR}/${PACKAGENAME}/DEBIAN"
    echo "backup current kernel..."
    cat << EOF > preinst
#!/bin/sh
echo "pre install job"
BACKUP_DIR="$(pwd)/boot-backup-\$(date +%m-%d-%Y_%H-%M)"
echo "Creating /boot backup in \${BACKUP_DIR}"
if [ ! -d "\${BACKUP_DIR}" ]; then
    mkdir "\${BACKUP_DIR}"
    cp -a /boot "\${BACKUP_DIR}"
    tar -cvf "\${BACKUP_DIR}".tar "./\${BACKUP_DIR}"
    rm -r "\${BACKUP_DIR}"
    # Doubt this bit belongs in preinst.
    # Will find it a better place later.
    # To also add initramfs entry replacement option
    sed -i 's/kernel=.*/kernel=${KERNELNAME}.img/' /boot/firmware/config.txt
fi
exit 0
EOF
    chmod 0755 preinst

    echo "creating control file..."
    cat << EOF > control
Package: ${PACKAGENAME}
Version: ${KERNELNAME}-1 
Architecture: ${ARCHITECTURE}
Maintainer: Pietro <github.com/psammarco>
Description: PREEMPT_RT rpi Linux kernel 
EOF

    echo "building debian package ${PACKAGENAME}.deb ..."
    cd ..
    mkdir /opt/pkg-deb
    dpkg-deb --build "${WORKDIR}/${PACKAGENAME}" ${PACKAGENAME}
    if [ $? -eq 0 ]; then
        mv "${WORKDIR}/${PACKAGENAME}/${PACKAGENAME}" "/opt/pkg-deb/${PACKAGENAME}-${KERNELNAME}-1.deb"
        echo "SUCCESS building /opt/pkg-deb/${PACKAGENAME}-${KERNELNAME}-1.deb"
    fi
}

function CLEAN(){
    rm -r "${WORKDIR}/${PACKAGENAME}"
    rm -r "/opt/pkg-deb/${PACKAGENAME}-${KERNELNAME}-1.deb"
    dpkg --purge "${PACKAGENAME}"
}

case "${1}" in
    create|CREATE|Create)
        if [ -z "${2}" ]; then 
            echo "You must provide the package name."
            exit 0
        else 
            PACKAGENAME="${2}"
        fi
        CREATE
        ;;
    clean|CLEAN|Clean)
        if [ -z "${2}" ]; then 
            echo "You must provide the package name."
            exit 0
        else 
            PACKAGENAME="${2}"
        fi
        CLEAN
        ;;
    *)
        echo -e "Unknown option ${1}\nOptions are: CREATE or CLEAN"
        ;;
esac
