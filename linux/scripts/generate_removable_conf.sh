#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

INPUT="/etc/removable-storage.conf"

OUTPUT="/var/run/removable-storage.conf"

add_jail() {
	local jail="${1}"
	local jailpath="/etc/jails/${jail}"

	TYPE=""
	ENCRYPTED_ID=""
	SIGNED_ID=""
	JAIL_NAME=""
	USB_USER=""

	source "${jailpath}/usb.storage"

	case "${TYPE}" in 
		admin)
			ADMIN_JAILS+=( "${jail}" )
			;;
		audit)
			AUDIT_JAILS+=( "${jail}" )
			;;
		user)
			USER_JAILS+=( "${jail}" )
			;;
	esac

	[[ -n "${ENCRYPTED_ID}" ]] && ENCRYPTED_IDS["${jail}"]="${ENCRYPTED_ID}"
	[[ -n "${SIGNED_ID}" ]] && SIGNED_IDS["${jail}"]="${SIGNED_ID}"
	[[ -n "${JAIL_NAME}" ]] && JAIL_NAMES["${jail}"]="${JAIL_NAME}"
	[[ -n "${USB_USER}" ]] && USB_USERS["${jail}"]="${USB_USER}"
}

add_all_jails() {
	local d jail

	for d in /etc/jails/*; do
		[[ -e "${d}/usb.storage" ]] || continue
		jail="${d##*/}"

		if [[ "${jail#rm_}" != "${jail}" ]]; then
			echo "${CLIP_JAILS}" | grep -qw "${jail}" || continue
			RM_JAILS+=( "${jail}" )
		fi

		add_jail "${jail}"
	done
}

write_output() {
	local jail key

	echo -n 'declare -a ADMIN_JAILS=( ' > "${OUTPUT}"
	for jail in "${ADMIN_JAILS[@]}" ; do 
		echo -n "\"${jail}\" " >> "${OUTPUT}"
	done
	echo ')' >> "${OUTPUT}"

	echo -n 'declare -a AUDIT_JAILS=( ' >> "${OUTPUT}"
	for jail in "${AUDIT_JAILS[@]}" ; do 
		echo -n "\"${jail}\" " >> "${OUTPUT}"
	done
	echo ')' >> "${OUTPUT}"

	echo -n 'declare -a USER_JAILS=( ' >> "${OUTPUT}"
	for jail in "${USER_JAILS[@]}" ; do 
		echo -n "\"${jail}\" " >> "${OUTPUT}"
	done
	echo ')' >> "${OUTPUT}"

	echo -n 'declare -a RM_JAILS=( ' >> "${OUTPUT}"
	for jail in "${RM_JAILS[@]}" ; do 
		echo -n "\"${jail}\" " >> "${OUTPUT}"
	done
	echo ')' >> "${OUTPUT}"

	echo 'declare -A JAIL_NAMES=(' >> "${OUTPUT}"
	for key in "${!JAIL_NAMES[@]}"; do
		echo "    [${key}]=\"${JAIL_NAMES[${key}]}\"" >> "${OUTPUT}"
	done
	echo ')' >> "${OUTPUT}"

	echo 'declare -A ENCRYPTED_IDS=(' >> "${OUTPUT}"
	for key in "${!ENCRYPTED_IDS[@]}"; do
		echo "    [${key}]=\"${ENCRYPTED_IDS[${key}]}\"" >> "${OUTPUT}"
	done
	echo ')' >> "${OUTPUT}"

	echo 'declare -A SIGNED_IDS=(' >> "${OUTPUT}"
	for key in "${!SIGNED_IDS[@]}"; do
		echo "    [${key}]=\"${SIGNED_IDS[${key}]}\"" >> "${OUTPUT}"
	done
	echo ')' >> "${OUTPUT}"

	echo 'declare -A USB_USERS=(' >> "${OUTPUT}"
	for key in "${!USB_USERS[@]}"; do
		echo "    [${key}]=\"${USB_USERS[${key}]}\"" >> "${OUTPUT}"
	done
	echo ')' >> "${OUTPUT}"
}

####### MAIN #######

source "${INPUT}"
source "/etc/conf.d/clip"

add_all_jails

write_output
