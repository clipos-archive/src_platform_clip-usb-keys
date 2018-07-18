#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# mount_usb.sh - mount available USB tokens.
# Authors: 	Florent Chabaud <clipos@ssi.gouv.fr>
#		Vincent Strubel <clipos@ssi.gouv.fr>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#

SCRIPT_NAME="MOUNT_USB"
XDIALOG_ERROR_TITLE="Montage de support USB"
DEVTYPE="usb"

source /lib/clip/usb_storage.sub || exit 1

ERROR_NO_AVAILABLE="Aucun support USB non monté n'est connecté au système"

function mount_available_usb()
{
	local ret=0
	local -a jails
	case "${CURRENT_USER_TYPE}" in 
		"privuser")
			jails=( "${PRIVUSER_JAILS[@]}" )
			;;
		"audit")
			jails=( "${AUDIT_JAILS[@]}" )
			;;
		"admin")
			jails=( "${ADMIN_JAILS[@]}" )
			;;
		*)
			jails=( "${USER_JAILS[@]}" )
			;;
	esac

	for block in /sys/block/sd* ; do
		local bname="${block##*/}"
		local removable="$(<"${block}/removable")"
		local size="$(<"${block}/size")"
		[[ "${removable}" == "1" ]] || continue 
		[[ ${size} -ne 0 ]] || continue
		# device is removable and present
		for jail in "${jails[@]}"; do
			grep -q "^/dev/${bname}" "${MTAB_PATH}/${jail}.mtab" && bname=""
		done
		if [[ -n "${bname}" ]]; then
			debug "got block device $bname"
			USB_LOCKED="true" DEVPATH="/block/${bname}" /lib/hotplug.d/usb_storage add 
			[[ $? -eq 0 ]] || ret=1
		fi
	done
	return $ret
}

####################################
############ MAIN CODE #############
####################################

exec 150>>"${USB_LOCKFILE}"
flock -x 150 || error "${ERROR_LOCK}"

get_user
mount_available_usb || error "${ERROR_NO_AVAILABLE}"
exit 0

