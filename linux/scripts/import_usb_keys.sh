#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# import_usb_keys.sh - import USB crypto keys from a USB support
# Author: Vincent Strubel <clipos@ssi.gouv.fr>
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
ERROR_GET_SYMKEY="Erreur de déchiffrement de la clé symétrique"
ERROR_MKDIR="Erreur dans la création du répertoire de clés"
ERROR_SYM_DECRYPT="Echec du déchiffrement symétrique"
ERROR_CLIP_DRIVE="Le support amovible est initiliasé pour CLIP au niveau"

#Debug messages
DEBUG_MOUNT="Mount OK"
DEBUG_CANCEL="Cancelled key export"

SCRIPT_NAME="IMPORT_USB_KEYS"
XDIALOG_ERROR_TITLE="Impport des clés cryptographiques USB"
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

function get_passwd()
{
	local title="Saisie du mot de passe d'import"
	local msg="Veuillez saisir le mot de passe protégeant les clés cryptographiques\n(mot de passe affiché lors de l'export)."

	PASSWORD=$(${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} \
			"${AUTHORITY}" \
			--stdout --wrap --password --title "${title}" \
			--inputbox "${msg}" 0 0)
	if [[ $? -ne 0 || -z "${PASSWORD}" ]]; then
		return 1
	fi
}

function do_import()
{
	local symkey="$(PASS="${PASSWORD}" output_stage2_key \
		"${BASE_INPUT}.settings" "PASS" "${BASE_INPUT}.key")"

	if [[ $? -ne 0 ]]; then
		error "${ERROR_GET_SYMKEY}"
	fi

	mkdir -p "${ROOT_USER_KEYS}" || error "${ERROR_MKDIR}"

	KEY="${symkey}" openssl aes-256-cbc -d -pass env:KEY \
				-salt -md sha256 -in "${BASE_INPUT}.tgz.crypt" | \
			tar -C "${ROOT_USER_KEYS}" -xzf - \
		|| error "${ERROR_SYM_DECRYPT} : $?"
}

function get_jail_popup_import()
{
	local title="Import des clés cryptographiques"
	local msg="Pour quel compartiment souhaitez-vous importer les clés cryptographiques ?"
	
	get_key_level "${title}" "${msg}"
}

####################################
############ MAIN CODE #############
####################################

get_connected_user

get_available_device || error "${ERROR_NO_DEVICE}"

get_jail_popup_import

get_user_paths

DISP_LEVEL="$(get_jail_name "${CURRENT_STR_LEVEL}")" 

# are we overwriting existing keys ?
if check_keys "nofail"; then
	TITLE="Ecrasement des clés ${DISP_LEVEL}"
	MESSAGE="Des clés cryptographiques existent déjà pour le niveau ${DISP_LEVEL}, souhaitez-vous les écraser ?"
	if ! x11_msg "${TITLE}" "${MESSAGE}" "yesno"; then
		info "${DEBUG_CANCEL}"
		exit 0
	fi
fi

# we won't import from an already initialized CLIP usb drive, whatever its level
# next call overwrites CURRENT_STR_LEVEL - should be ok since we bail
# out immediately afterwards.
if test_level; then
	error "${ERROR_CLIP_DRIVE} $(get_jail_name ${CURRENT_STR_LEVEL})"
fi

BASE_INPUT="${CORE_MOUNT_POINT}/${CURRENT_USER}-${CURRENT_STR_LEVEL}"

if ! get_passwd; then
	info "${DEBUG_CANCEL}"
	exit 0
fi

mount_device
do_import
umount_device

rm -f ${LASTDEV_FILE}

TITLE="Import des clés de niveau ${DISP_LEVEL}"
MESSAGE="Les clés de niveau ${DISP_LEVEL} ont été importées."

x11_msg "${TITLE}" "${MESSAGE}"
