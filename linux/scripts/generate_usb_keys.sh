#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# generate_usb_keys.sh - generate USB crypto keys.
# Author: Vincent Strubel <clipos@ssi.gouv.fr>
# Based on code by EADS DCS and EADS IW
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#

#Error messages
ERROR_PASSPHRASE_CONFIRM="Les deux mots de passe ne correspondent pas"
ERROR_SSH="Erreur dans la génération de la clé privée"
ERROR_SSL="Erreur dans la génération de la clé publique"
ERROR_MKDIR="Erreur dans la création des répertoires de clés"
ERROR_REMOVE="Impossible de supprimer la clé existante : "

#Debug messages
DEBUG_CANCEL="Cancelled key generation"

SCRIPT_NAME="GENERATE_USB_KEYS"
XDIALOG_ERROR_TITLE="Creation des cles cryptographiques USB"
source /lib/clip/usb_storage.sub || exit 1

####################################
############ Util code #############
####################################


function clean_up()
{
	[[ -n "${USER_CRYPT_KEYS}" ]] && rm -fr "${USER_CRYPT_KEYS}"
	[[ -n "${USER_SIGN_KEYS}" ]] && rm -fr "${USER_SIGN_KEYS}"
	[[ -d "${ROOT_USER_KEYS}" ]] && \
		rmdir "${ROOT_USER_KEYS}" 2>/dev/null # Remove only if empty !
}

function warn_if_exists()
{
	check_keys "nofail" || return 0

	local msg="Des clés ont déjà été générées pour le niveau ${DISP_LEVEL}.\nLa régénération des clés écrasera les anciennes clés,\net interdira le montage des supports initialisés avec celles-ci.\nEtes-vous sûr de vouloir régénérer les clés de niveau ${DISP_LEVEL} ?"
	local title="Génération des clés de niveau ${DISP_LEVEL}"

	if ! ${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" \
			--left --wrap --title "${title}" --yesno "${msg}" 0 0
	then
		info "${DEBUG_CANCEL}"
		exit 0
	fi
}

function gen_one_key()
{
	local typ="${1}"
	local prv="${2}"
	local pub="${3}"
	
	[[ -n "${pub}" ]] || error "gen_one_key: not enough arguments"

	local pass="$(gen_passphrase "${typ}" "${PASSPHRASE}")"

	rm -f "${prv}"
	[[ -f "${prv}" ]] && error "${ERROR_REMOVE} ${prv}"
	${SSH_KEYGEN} -t rsa -b "${RSA_SIZE}" -f "${prv}" \
			-C "${CURRENT_USER}-${typ}@clip" -N "${pass}" 1>/dev/null \
		|| error "${ERROR_SSH} : $?"

	openssl rsa -in "${prv}" -pubout -out "${pub}" \
			-passin pass:"${pass}" 1>/dev/null \
		|| error "${ERROR_SSL} : $?"
	rm -f "${prv}.pub" 1>/dev/null
}

function gen_keys()
{
	mkdir -p "${USER_CRYPT_KEYS}" "${USER_SIGN_KEYS}"
	[[ $? -eq 0 ]] || error "${ERROR_MKDIR} : $?"

	get_passphrase "génération" || error "${ERROR_PASSPHRASE}"
	get_passphrase "génération" "confirm" || error "${ERROR_PASSPHRASE}"
	if [[ "${PASSPHRASE}" != "${PASSPHRASE_CONFIRM}" ]]; then
		error "${ERROR_PASSPHRASE_CONFIRM}"
	fi

	gen_one_key "enc" "${CRYPT_PRV_KEY}" "${CRYPT_PUB_KEY}"
	gen_one_key "sig" "${SIGN_PRV_KEY}" "${SIGN_PUB_KEY}"
}

function get_jail_popup_generate()
{
	local title="Génération des clés cryptographiques"
	local msg="Pour quel compartiment souhaitez-vous générer des clés cryptographiques ?"
	
	get_key_level "${title}" "${msg}"
}

####################################
############ MAIN CODE #############
####################################

get_connected_user

get_jail_popup_generate

get_user_paths

DISP_LEVEL="$(get_jail_name "${CURRENT_STR_LEVEL}")"
warn_if_exists

gen_keys

XDIALOG_TITLE="Création des cles de niveau ${DISP_LEVEL}"
XDIALOG_MESSAGE="Clés de niveau ${DISP_LEVEL} créées."

${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" \
		--title "${XDIALOG_TITLE}" --msgbox "${XDIALOG_MESSAGE}" 6 80 \
	|| error "${ERROR_XDIALOG}"

exit 0
