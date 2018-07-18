#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# export_usb_keys.sh - export USB crypto keys on a USB support
# Author: Vincent Strubel <clipos@ssi.gouv.fr>
# Based on code by EADS DCS
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#

#Error messages
ERROR_NO_DEVICE="Aucun support n'est présent pour l'export"
ERROR_MOUNT="Echec lors du montage de la clé USB d'export"
ERROR_MOUNT_ALREADY="Cle USB d'export déjà montée"
ERROR_UMOUNT="Echec lors du démontage de la clé USB d'export"
ERROR_GEN_SYMKEY="Erreur dans la génération de la clé symétrique"
ERROR_GEN_PASSWD="Erreur dans la génération du mot de passe"
ERROR_GEN_SALT="Erreur dans la génération des paramètres de chiffrement"
ERROR_ENC_KEY="Erreur dans le chiffrement de la clé symétrique"
ERROR_SYM_CRYPT="Echec du chiffrement symétrique"
ERROR_CLIP_DRIVE="Le support amovible est initiliasé pour CLIP au niveau"

#Debug messages
DEBUG_MOUNT="Mount OK"
DEBUG_CANCEL="Cancelled key export"

SCRIPT_NAME="EXPORT_USB_KEYS"
XDIALOG_ERROR_TITLE="Export des clés cryptographiques USB"
DEVTYPE="usb"
source /lib/clip/usb_storage.sub || exit 1
source /lib/clip/userkeys.sub || exit 1

CORE_MOUNT_POINT="/mnt/usb"
MTAB_FILE="${MTAB_PATH}/core.mtab"

####################################
############ Util code #############
####################################


function clean_up()
{
	umount_device
}

function mount_device()
{
	if grep -q "^${DEVICE_DATA} ${CORE_MOUNT_POINT}" "${MTAB_FILE}"; then
		error "${ERROR_MOUNT_ALREADY}"
	fi

	mount -t vfat -o rw,nosuid,noexec,nodev "${DEVICE_DATA}" \
						"${CORE_MOUNT_POINT}"	
	if [[ $? -ne 0 ]]; then
		error "${ERROR_MOUNT} : $?"
	fi

	local mtabstr="${DEVICE_DATA} ${CORE_MOUNT_POINT} vfat rw,nosuid,noexec,nodev"

	[[ -f "${MTAB_FILE}" ]] || touch "${MTAB_FILE}"
	flock "${MTAB_FILE}" echo "${mtabstr}" >> "${MTAB_FILE}"
	if [[ $? -ne 0 ]]; then
		warn_nox11 "Failed to update mtab file"
	fi

	debug "${DEBUG_MOUNT}"
}


function umount_device()
{
	if ! grep -q "^${DEVICE_DATA} ${CORE_MOUNT_POINT}" "${MTAB_FILE}"; then
		warn_nox11 "Mount not found in the mtab file"
		return 0
	fi

	umount "${CORE_MOUNT_POINT}"
	if [[ $? -ne 0 ]]; then
		error "${ERROR_UMOUNT} : $?"
	fi
	local mtabstr="${DEVICE_DATA} ${CORE_MOUNT_POINT} vfat rw,nosuid,noexec,nodev"
	mtabstr="$(echo "${mtabstr}" | sed -e "s:\/:\\\/:g")"

	flock "${MTAB_FILE}" sed -i -e "/${mtabstr}/d" "${MTAB_FILE}"
}

function do_export()
{
	local symkey="$(tr -cd '[:graph:]' < "${RANDOM_FILE}" | head -c 80)"
	if [[ $? -ne 0 ]]; then
		error "${ERROR_GEN_SYMKEY}"
	fi
	PASSWD="$(tr -cd '[:alnum:]' < "${RANDOM_FILE}" | head -c 16)"
	if [[ $? -ne 0 ]]; then
		error "${ERROR_GEN_PASSWD}"
	fi

	echo -n '$2a$12$' > "${BASE_OUTPUT}".settings || error "${ERROR_GEN_SALT}"
	_read_salt >> "${BASE_OUTPUT}".settings || error "${ERROR_GEN_SALT}"
	echo -n "${symkey}" | PASS="${PASSWD}" encrypt_stage2_key \
			"${BASE_OUTPUT}.settings" "PASS" "${BASE_OUTPUT}.key" "pw" \
			|| error "${ERROR_ENC_KEY}"

	tar -C "${ROOT_USER_KEYS}" -czf - crypt sig | \
		PASS="${symkey}" openssl aes-256-cbc -e -pass env:PASS \
			-salt -md sha256 -out "${BASE_OUTPUT}".tgz.crypt \
		|| error "${ERROR_SYM_CRYPT} : $?"
}

function get_jail_popup_export()
{
	local title="Export des clés cryptographiques"
	local msg="Pour quel compartiment souhaitez-vous exporter les clés cryptographiques ?"
	
	get_key_level "${title}" "${msg}"
}

####################################
############ MAIN CODE #############
####################################

get_connected_user

get_available_device || error "${ERROR_NO_DEVICE}"

get_jail_popup_export

get_user_paths

# are there any keys to export ?
check_keys

# we won't export to an already initialized CLIP usb drive, whatever its level
# next call overwrites CURRENT_STR_LEVEL - should be ok since we bail
# out immediately afterwards.
if test_level; then
	error "${ERROR_CLIP_DRIVE} $(get_jail_name ${CURRENT_STR_LEVEL})"
fi

BASE_OUTPUT="${CORE_MOUNT_POINT}/${CURRENT_USER}-${CURRENT_STR_LEVEL}"
DISP_LEVEL="$(get_jail_name "${CURRENT_STR_LEVEL}")" 

# key export is a sensitive operation - let's ask the user for confirmation every time.
MESSAGE="Etes-vous sûr de vouloir exporter les clés cryptographiques de niveau ${DISP_LEVEL} ?"
TITLE="Export des clés de support USB ${DISP_LEVEL}"
if ! x11_msg "${TITLE}" "${MESSAGE}" "yesno"; then
	info "${DEBUG_CANCEL}"
	exit 0
fi

mount_device
do_export
umount_device

rm -f ${LASTDEV_FILE}

TITLE="Export des clés de niveau ${DISP_LEVEL}"
MESSAGE="Les clés de niveau ${DISP_LEVEL} ont été exportées, avec le mot de passe ${PASSWD}.
\nN.B. : ce mot de passe sera nécessaire pour l'import."

x11_msg "${TITLE}" "${MESSAGE}"
