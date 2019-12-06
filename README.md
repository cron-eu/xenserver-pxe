# xenserver-pxe

Abstract
----

Unattended Setup of XenServer Hypervisor on bare metal. This document describes how to setup the requied pxe environment
(tftp, dhcp and http server) for Debian flavored systems.

### Clone this repo

```bash
git clone https://github.com/cron-eu/xenserver-pxe
cp .env.example .env
vi .env # tweak the settings there
```

### Setup and Configure the PXE Boot Environment
 
Setup for Debian based systems, e.g. Debian Buster.

```bash
# install required packages
aptitude install isc-dhcp-server tftpd-hpa syslinux-utils lighttpd
lighttpd-enable-mod access
service lighttpd force-reload

# enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf

cp configuration-sample/dhcp/dhcpd.conf /etc/dhcp/
vi /etc/dhcp/dhcpd.conf # change configuration as needed

# make sure the DHCP Server is listening on the right interface
cat <<EOF >> /etc/default/isc-dhcp-server
INTERFACESv4="eth1"
INTERFACESv6=""
EOF
```

### Setup XenServer PXE Environment

#### Prerequisites

XenServer ISO file. Download it from here (signup needed):

https://www.citrix.com/downloads/citrix-hypervisor/product-software/hypervisor-80-express-edition.html

ENV vars

```bash
. .env
CITRIX_INSTALLER_NAME="CitrixHypervisor-${CITRIX_VERSION}-install"
```

Mount the ISO file on /mnt and copy files

```bash
mount -t loop,ro ~/${CITRIX_INSTALLER_NAME}-cd.iso /mnt
cp -a /mnt /var/www/html/${CITRIX_INSTALLER_NAME}
umount /mnt
# rm -f ~/${CITRIX_INSTALLER_NAME}-cd.iso
```

Create the answerfile for unattended setup:


```bash
CITRIX_INSTALLER_NAME="CitrixHypervisor-${CITRIX_VERSION}-install"
URL="${HTTPHOST_BASEURL}/{CITRIX_INSTALLER_NAME}"

file=/var/www/html/${CITRIX_INSTALLER_NAME}-answerfile
cp configuration-sample/xen-setup/answerfile.xml $file 

sed -i "s/ROOT_PASSWORD/$(openssl rand -base64 32)/" $file 
sed -i "s/SOURCE_URL/$URL" $file

# Copy the PXE related files from the Installer bundle:

mkdir -p /srv/tftp/pxelinux.cfg
cp /var/www/html/${CITRIX_INSTALLER_NAME}/boot/pxelinux/* /srv/tftp/ 

# Copy the Xen Installer from bundle:

xen_installer_dir=/srv/tftp/xen-installer-${CITRIX_VERSION}
mkdir -p ${xen_installer_dir}
cp -a /var/www/html/${CITRIX_INSTALLER_NAME}/boot/* ${xen_installer_dir}
cp /var/www/html/${CITRIX_INSTALLER_NAME}/install.img ${xen_installer_dir}
```

Copy archlinux pxe files (used for the rescue image)

```bash
s3=http://cron-devop-downloads.s3-website.eu-central-1.amazonaws.com
mkdir -p /var/www/html/archlinux
cp ${s3}/archlinux/vmlinuz_i686 /var/www/html/archlinux
cp ${s3}/archlinux/initramfs_i686.img /var/www/html/archlinux
```

Done!

### set-pxe.sh

`set-pxe.sh` is a shell script to configure a PXE configuration file for a specific IP address.

