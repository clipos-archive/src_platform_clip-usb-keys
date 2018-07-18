#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# clear_usb_key.sh - re-initialize a USB token as a cleartext, VFAT
# support
# Author: Vincent Strubel <clipos@ssi.gouv.fr>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#

#Error messages
ERROR_NO_DEVICE="Aucun support effaçable n'est présent.
N.B. : les supports montés ne peuvent pas être effacés."
ERROR_GETSZ="Impossible de lire la taille du périphérique"
ERROR_FILL="Erreur lors de la remise à zéro du périphérique"
ERROR_PART="Erreur lors du partitionnement du périphérique"
ERROR_FS_CREATE="Erreur lors de la création du système de fichiers"

SCRIPT_NAME="CLEAR_USB"
XDIALOG_ERROR_TITLE="Effacement de clé USB"
DEVTYPE="usb"
source /lib/clip/usb_storage.sub || exit 1


########################################
############# Init Key Code ############
########################################

function clear_device()
{
	local size=

	size="$(blockdev --getsz "${BASE_DEVICE}")"
	[[ $? -eq 0 && -n "${size}" ]] || error "${ERROR_GETSZ}"
	local ksize=$(( ${size} / 2 ))

	local title="Effacement en cours"
	local msg="Effacement du support USB en cours. L'effacement peut prendre plusieurs minutes, en fonction \nde la taille du support. Merci de patienter (cette fenêtre se fermera automatiquement)."

	(dd if=${ZERO_FILE} bs=512 count="${size}" 2>/dev/null \
			| pv -n -s "${ksize}k" \
			| dd bs=512 of="${BASE_DEVICE}" \
				1>/dev/null 2>/dev/null ) 2>&1 \
		| ${USER_ENTER} -u "${CURRENT_UID}" -- \
			${DIALOG} "${AUTHORITY}" --wrap \
			--left --no-buttons --no-cancel --no-ok \
			--title "${title}" --gauge "${msg}" 0 0
	local -i ret=$?


	[[ $ret -eq 0 ]] || error "${ERROR_FILL}: ${BASE_DEVICE}"

	local cyls=""
	cyls="$(sfdisk -g ${BASE_DEVICE} | awk '{print $2}')"

	[[ $? -eq 0 ]] || error "${ERROR_PART}"

	sfdisk ${BASE_DEVICE} >/dev/null 2>&1 <<EOF
,${cyls},b
;
;
;
EOF
	[[ $? -eq 0 ]] || error "${ERROR_PART}"

	mkfs.vfat ${DEVICE_DATA} >/dev/null 2>&1 \
		|| error "${ERROR_FS_CREATE}"
}

function confirm_clear() {
	local title="Confirmation de l'effacement"
	local msg="Confirmez-vous l'effacement du support USB ?"
	msg="${msg}\nATTENTION : l'effacement d'un support supprime les données qu'il contient."
	msg="${msg}\nIl est également à noter que l'effacement ne peut pas garantir l'absence de données rémanentes sur le support. Par conséquent, un tel effacement ne doit pas être utilisé pour réinitialiser à un niveau inférieur un support précédemment initialisé sans chiffrement."
	
	${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --wrap \
			--left --title "${title}" --yesno "${msg}" 12 100 \
		|| exit 0
}


####################################
############ MAIN CODE #############
####################################

exec 150>>"${USB_LOCKFILE}"
flock -x 150 || error "${ERROR_LOCK}"

get_connected_user

get_available_device || error "${ERROR_NO_DEVICE}"

confirm_clear

clear_device

rm -f "${LASTDEV_FILE}"

${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --wrap \
	--title "Effacement terminé" --no-cancel --msgbox \
	"Le périphérique a été effacé et formaté avec succès" 0 0

exit 0




