#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# umount_usb.sh - unmount a mounted CLIP USB token.
# Author: Vincent Strubel <clipos@ssi.gouv.fr>
# Based on code by EADS DCS and EADS IW
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#

SCRIPT_NAME="UMOUNT_USB"
XDIALOG_ERROR_TITLE="Démontage du support USB"
DEVTYPE="usb"

source /lib/clip/usb_storage.sub || exit 1

#Error messages
ERROR_NOT_MOUNTED="Aucun support USB n'est actuellement monté dans la cage"


####################################
############ MAIN CODE #############
####################################

exec 150>>"${USB_LOCKFILE}"
flock -x 150 || error "${ERROR_LOCK}"

get_connected_user
get_umount_level

for level in ${LEVEL_ASKED}; do
	info "Unmounting ${level}"
	if ! get_jail_device_by_level "${level}"; then
		error "${ERROR_NOT_MOUNTED} $(get_jail_name ${JAIL})"
	fi
	if test_level; then
		[[ "${CURRENT_STR_LEVEL}" == "${STR_ANY}" ]] && CURRENT_STR_LEVEL="${level}"
		# Do some minimal checking - no signature check
		check_level "${level}" "nocheck"
	else
		CURRENT_STR_LEVEL="${level}"
		CLEARTEXT_MOUNT="yes"
		MOUNT_RO="yes"
	fi

	umount_device
done
exit 0

