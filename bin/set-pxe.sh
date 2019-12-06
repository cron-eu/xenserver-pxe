#!/bin/bash

##
# Setup a configuration file for PXE booting for a given MAC Address
#
# This script needs the gethostip util:
# apt-get install syslinux-utils
#

# shellcheck source=../.env
. "$(dirname "$0")/../.env"

function usage {
	echo "Usage: $0 <IP address or hostname> [ rescue | xenserver-auto | off ]"
	exit 1
}

function error {
	echo "ERROR: $*"
	exit 2
}

if [ -z "$CITRIX_VERSION" ]; then
	error "ENV VAR CITRIX_VERSION not set"
fi

echo "Using XenServer Version: ${CITRIX_VERSION}"

installer_name="CitrixHypervisor-${CITRIX_VERSION}-install"
xen_pxe_dir="xen-installer-${CITRIX_VERSION}"

host="$1"; shift
action="$1"; shift

if [ -z "$action" ]; then
	usage
fi

filename="/srv/tftp/pxelinux.cfg/$(gethostip -x "$host")"
host_ip=$(gethostip -n "$host")

if [ -z "$filename" ]; then
	error "Could not build the PXE config file name"
fi

echo "Using PXE configuration file: $filename"

case $action in
off)
	rm -f "$filename"
	echo "PXE configuration removed for ip ${host_ip}"
	;;

rescue)
	cat <<EOF > "$filename"
default $action
label $action
        kernel archlinux/vmlinuz_i686
	append initrd=archlinux/initramfs_i686.img
EOF
	echo "PXE action set to $action for ip ${host_ip}"
	;;

xenserver-auto)
	cat <<EOF > "$filename"
default $action
label $action
	kernel mboot.c32
	append ${xen_pxe_dir}/xen.gz dom0_max_vcpus=1-16 dom0_mem=max:8192M com1=115200,8n1 console=com1,vga --- ${xen_pxe_dir}/vmlinuz xencons=hvc console=hvc0 console=tty0 answerfile=${HTTPHOST_BASEURL}/${installer_name}-answerfile install --- ${xen_pxe_dir}/install.img
EOF
	echo "PXE action set to $action for ip ${host_ip}"
	;;

*)
	usage
	;;
esac
