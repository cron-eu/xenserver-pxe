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

Symlink PXE-boot files from the XenServer installer bundle:

```bash
mkdir -p /srv/tftp/pxelinux.cfg
ln -s /var/www/html/${CITRIX_INSTALLER_NAME}/boot/pxelinux/pxelinux.0 /srv/tftp/pxelinux.0
ln -s /var/www/html/${CITRIX_INSTALLER_NAME}/boot/pxelinux/menu.c32 /srv/tftp/menu.c32 
ln -s /var/www/html/${CITRIX_INSTALLER_NAME}/boot/pxelinux/mboot.c32 /srv/tftp/mboot.c32 
```

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

#### Examples

Install XenServer on a server named `clms306.ffm`:

```bash
# set-pxe.sh clms306.ffm xenserver-auto
Using XenServer Version: 8.0.0
Using PXE configuration file: /srv/tftp/pxelinux.cfg/C0A8061C
PXE action set to xenserver-auto for ip clms306.ffm
```

This will generate the PXE file `/srv/tftp/pxelinux.cfg/C0A8061C` (clms306.ffm having the internal IP 192.168.6.28):

After reboot, the server will run the XenServer Installer and install the Xen Hypervisor in the configured version.

Monitor the logs using:

```bash
tail -f /var/log/syslog /var/log/lighttpd/access.log
```

While the installer is running (after the server fetches the answerfile):

```
192.168.6.28 service.ffm - [05/Dec/2019:20:36:43 +0100] "GET /xeninstall-answerfile80 HTTP/1.1" 200 330 "-" "curl/7.15.5 (i686-redhat-linux-gnu) libcurl/7.15.5 OpenSSL/0.9.8b zlib/1.2.3 libidn/0.6.5"
```

Revert the PXE setup so the server will be able to boot from the local drive:

```bash
# set-pxe.sh clms306.ffm off
Using XenServer Version: 8.0.0
Using PXE configuration file: /srv/tftp/pxelinux.cfg/C0A8061C
PXE configuration removed for ip clms306.ffm
```

This will basically remove the PXE configuration file for the specific ip.
