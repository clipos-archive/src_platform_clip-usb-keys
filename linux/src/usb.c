// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright © 2007-2018 ANSSI. All Rights Reserved.

/**
 * usb.c
 *
 * @brief usb listen to the socket /var/run/usbxx and executes the command asked. Command can be to unmount, initialize a usb key, or generate or export cryptographic keys.
 * @see usbadmin
 *
 **/


#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <pwd.h>
#include <grp.h>
#include <signal.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <errno.h>
#include <syslog.h>
#include <fcntl.h>
#include <arpa/inet.h>

#include <clip.h>

#include "usb.h"

#define LEVEL_CHARS	4

#define MOUNT_COMMAND 'M'
#define MOUNT_SCRIPT "/sbin/mount_usb.sh"
#define UMOUNT_COMMAND 'U'
#define UMOUNT_SCRIPT "/sbin/umount_usb.sh"
#define INIT_COMMAND 'I'
#define INIT_COMMAND_NOCRYPT 'i'
#define INIT_SCRIPT "/sbin/init_usb_key.sh"
#define GENERATE_COMMAND 'G'
#define GENERATE_SCRIPT "/sbin/generate_usb_keys.sh"
#define EXPORT_COMMAND 'E'
#define EXPORT_SCRIPT "/sbin/export_usb_keys.sh"
#define IMPORT_COMMAND 'D'
#define IMPORT_SCRIPT "/sbin/import_usb_keys.sh"
#define CLEAR_COMMAND 'e'
#define CLEAR_SCRIPT "/sbin/clear_usb_key.sh"
#define CD_MOUNT_COMMAND 'C'
#define CD_MOUNT_SCRIPT "/sbin/mount_cdrom.sh"
#define CD_UMOUNT_COMMAND 'c'
#define CD_UMOUNT_SCRIPT "/sbin/umount_cdrom.sh"

#define ERROR(fmt, args...) \
	syslog(LOG_DAEMON|LOG_ERR, fmt, ##args)

#define INFO(fmt, args...) \
	syslog(LOG_DAEMON|LOG_INFO, fmt, ##args)

#define PERROR(msg) \
	syslog(LOG_DAEMON|LOG_ERR, msg ": %s", strerror(errno))



static int launch_script(char *script, char *arg)
{
	int ret, fd;
	char *const argv[] = { script, arg, NULL };
	char *envp[] = { NULL };
	if (arg)
		INFO("Running %s with arg %s", 
				script, arg);
	else
		INFO("Running %s", script);

	fd = open("/dev/null", O_RDWR|O_NOFOLLOW);
	if (fd < 0) {
		PERROR("failed to open /dev/null");
		return -1;
	}
	if (dup2(fd, STDIN_FILENO) < 0) {
		PERROR("failed to set stdin for script");
		return -1;
	}
	if (dup2(fd, STDOUT_FILENO) < 0) {
		PERROR("failed to set stdout for script");
		return -1;
	}
	if (dup2(fd, STDERR_FILENO) < 0) {
		PERROR("failed to set stderr for script");
		return -1;
	}
	if (fd > STDERR_FILENO) /* fd could already be stderr */
		(void)close(fd); 

	ret = -execve(argv[0], argv, envp);
	if (ret)
		ERROR("command %s failed", script);
	return ret;
}

static int launch_init_nocrypt(void)
{
	int ret;
	char *str = strdup("clear");
	if (!str) {
		ERROR("Out of memory");
		return -1;
	}
	ret = launch_script(INIT_SCRIPT, str);
	free(str);
	return ret;
}

int start_usb_daemon(const char *socket_path)
{
	int s, s_com, status;
	pid_t f, wret;
	socklen_t len;
	struct sockaddr_un sau;
	char command=0;
	int ret = 1;

	openlog("USBADMIN", LOG_PID, LOG_DAEMON);
	
	/* We will write to a socket that may be closed on client-side, and
	   we don't want to die. */
	if (signal(SIGPIPE, SIG_IGN) == SIG_ERR) {
		PERROR("signal");
		goto out_free;
	}
          
        INFO("Start listening to %s ...", socket_path);
        
        s = clip_sock_listen(socket_path, &sau, 0);
        
        if (s < 0) {
          goto out_free;
        }
        
	for (;;) {
		len = sizeof(struct sockaddr_un);
		s_com = accept(s, (struct sockaddr *)&sau, &len);
		if (s_com < 0) {
			PERROR("accept");
			close(s);
			goto out_free;
		}

		INFO("Connection accepted");

		/* Get the command */
		if (read(s_com, &command, 1) != 1)
		{
			PERROR("read command");
			close(s_com);
			continue;
		}

		INFO("Command %c",command);

		f = fork();
		if (f < 0) {
			PERROR("fork");
			close(s_com);
			continue;
		} else if (f > 0) {
			/* Father */
			wret = waitpid(f, &status, 0);
			if (wret < 0) {
				PERROR("waitpid");
				if (write(s_com, "N", 1) != 1)
					PERROR("write N");
			}
			if (!WEXITSTATUS(status)) {
				if (write(s_com, "Y", 1) != 1)
					PERROR("write Y");
			} else {
				if (write(s_com, "N", 1) != 1)
					PERROR("write N");
			}
			close(s_com);
			continue;
		} else {
			/* Child */
			close(s);

			switch (command)
			{
				case INIT_COMMAND_NOCRYPT:
					exit(launch_init_nocrypt());
					break;
				case INIT_COMMAND:
					exit(launch_script(INIT_SCRIPT, NULL));
					break;
				case MOUNT_COMMAND:
					exit(launch_script(MOUNT_SCRIPT, NULL));
					break;
				case UMOUNT_COMMAND:
					exit(launch_script(UMOUNT_SCRIPT, NULL));
					break;
				case GENERATE_COMMAND:
					exit(launch_script(GENERATE_SCRIPT, NULL));
					break;
				case EXPORT_COMMAND:
					exit(launch_script(EXPORT_SCRIPT, NULL));
					break;
				case IMPORT_COMMAND:
					exit(launch_script(IMPORT_SCRIPT, NULL));
					break;
				case CLEAR_COMMAND:
					exit(launch_script(CLEAR_SCRIPT, NULL));
					break;
				case CD_MOUNT_COMMAND:
					exit(launch_script(CD_MOUNT_SCRIPT, NULL));
					break;
				case CD_UMOUNT_COMMAND:
					exit(launch_script(CD_UMOUNT_SCRIPT, NULL));
					break;
				default:
					ERROR("invalid command: %c", command);
					exit(-1);
			}
		}
	}

	INFO("Stop listening...");
	ret = 0;

out_free:
	return ret;
}
