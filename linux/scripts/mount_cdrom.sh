#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# mount_cdrom.sh: mount a CDROM in a CLIP jail
# Author: Vincent Strubel <clipos@ssi.gouv.fr>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#

SCRIPT_NAME="MOUNT_CDROM"
XDIALOG_ERROR_TITLE="Montage du CDROM"
DEVTYPE="cdrom"

source /lib/clip/usb_storage.sub || exit 1

#Debug messages
DEBUG_CANCEL="Cancelled CD mount"

#Error messages

function get_jail_popup_ro() {
	local title="Montage d'un support ${DEVTYPE_NAME} en lecture seule"
	local msg="Dans quel compartiment souhaitez vous monter le support ${DEVTYPE_NAME} ?"

	get_jail_popup "${title}" "${msg}"
}

####################################
############ MAIN CODE #############
####################################

CLEARTEXT_MOUNT="yes"

get_connected_user

get_jail_popup_ro || exit 1

get_device_from_file

check_device "${DEVICE_DATA}"

check_not_mounted

DISP_LEVEL="$(get_jail_name "${CURRENT_STR_LEVEL}")" 
# There is no automatic level check on CD-ROM mount - ask user for confirmation
XDIALOG_MESSAGE="Confirmez-vous le montage du CDROM au niveau ${DISP_LEVEL} ?"
XDIALOG_TITLE="Montage du CDROM au niveau ${DISP_LEVEL}"
if ! ${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" \
	--title "${XDIALOG_TITLE}" --yesno "${XDIALOG_MESSAGE}" 0 0
then
	info "${DEBUG_CANCEL}"
	exit 0
fi

map_device

mount_device

exit 0

