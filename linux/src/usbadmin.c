// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright © 2007-2018 ANSSI. All Rights Reserved.

/**
 * usbadmin.c
 *
 * @brief usbadmin starts a daemon listening to the socket /var/run/usbxx
 * @see usbclt
 *
 **/

#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string.h>
#include <sys/wait.h>

#include <clip.h>

#include "usb.h"

#define _TO_STR(var) #var
#define TO_STR(var) _TO_STR(var)

static inline void
print_help(const char *prog)
{
	printf("%s [-hv] [-s <socket_path>] [-u <update_group>]\n", prog);
	puts("Options:");
	puts("\t-u: set group to run UPDATE actions");
	puts("\t-s: add socket path");
	puts("\t-h: print this help and exit");
	puts("\t-v: print the version number and exit");
}

static inline void
print_version(const char *prog)
{
	printf("%s - Version %s\n", prog, TO_STR(VERSION));
}

int update_capable = 0;
const char *update_group = NULL;



#define MAX_NB_SOCKET_PATHS 4

static char *socket_paths[MAX_NB_SOCKET_PATHS];
static unsigned int nb_socket_paths = 0;


int main(int argc __attribute__((unused)), char *argv[])
{
	char *exe;
	int c;
        unsigned int i;
        pid_t pids[MAX_NB_SOCKET_PATHS];
        
	if (argv[0]) {
		exe = basename(argv[0]);
	} else {
		exe = "usbadmin";
	}

	while ((c = getopt(argc, argv, "hvs:u:")) != -1) {
		switch (c) {
			case 'h':
				print_help(exe);
				return EXIT_SUCCESS;
				break;
			case 'v':
				print_version(exe);
				return EXIT_SUCCESS;
				break;
			case 's':
				if (nb_socket_paths >= MAX_NB_SOCKET_PATHS) {
					fputs("Exhausted available socket paths\n", stderr);
					return EXIT_FAILURE;
				}
                                socket_paths[nb_socket_paths] = strdup(optarg);
                                ++nb_socket_paths;
				break;
			case 'u':
				if (update_group) {
					fputs("Dual update group option\n", stderr);
					return EXIT_FAILURE;
				}
				update_group = strdup(optarg);
				break;
			default:
				fputs("Invalid option\n", stderr);
				return EXIT_FAILURE;
				break;
		}
	}
				
	argv += optind;
	argc -= optind;
		
	if (update_group) 
		update_capable = 1;

	if (clip_daemonize()) {
          fputs("clip_fork", stderr);
		goto main_out_free;
	}
        
        for(i = 0; i < nb_socket_paths; ++i) {
          pids[i] = fork();
          
          if(pids[i] < 0) {
            fputs("Error during fork\n", stderr);
            continue;
          } else if (pids[i] == 0) {
            /* child */
            if (start_usb_daemon(socket_paths[i])) {
              fputs("Error starting USB_DAEMON\n", stderr);
              return EXIT_FAILURE;
            }
            return 0;
          }
        }
        
 main_out_free:
        
        for(i = 0; i < nb_socket_paths; ++i) {
          (void)waitpid(pids[i], NULL, 0);
          free(socket_paths[i]);
        }
        nb_socket_paths = 0;
        
        return EXIT_FAILURE;
}
