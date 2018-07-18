// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright © 2007-2018 ANSSI. All Rights Reserved.

/**
 * usb.h
 *
 * @brief usb listen to the socket /var/run/usbs and executes the command asked. Command can be to mount, unmount or initialize a usb key.
 * @see usbadmin
 *
 **/


#ifndef _USB_H
#define _USB_H_

extern int start_usb_daemon(const char *socket_path);
extern int update_capable;
extern const char *update_group;

#endif
