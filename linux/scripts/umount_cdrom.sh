#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# umount_cdrom.sh - unmount a CD-ROM in a CLIP jail
# Author: Vincent Strubel <clipos@ssi.gouv.fr>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#

SCRIPT_NAME="UMOUNT_CDROM"
XDIALOG_ERROR_TITLE="Démontage du CDROM"
DEVTYPE="cdrom"

EJECT="/usr/bin/eject"

source /lib/clip/usb_storage.sub || exit 1

#Error messages
ERROR_NOT_MOUNTED="Aucun CDROM n'est monté dans le compartiment"
ERROR_EJECT="Impossible d'éjecter le périphérique"

####################################
############ MAIN CODE #############
####################################

CLEARTEXT_MOUNT="yes"

get_connected_user

get_umount_level

for level in ${LEVEL_ASKED}; do
	info "unmounting cdrom on level ${level}"
	
	get_jail_device_by_level "${level}"
	if [[ $? -ne 0 ]]; then
		error "${ERROR_NOT_MOUNTED} ${JAIL}"
	fi
	CURRENT_STR_LEVEL="${level}"

	umount_device

	${EJECT} "${BASE_DEVICE}" \
		|| error "${ERROR_EJECT} ${BASE_DEVICE}"
done
exit 0

