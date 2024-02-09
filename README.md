# dev-tools
Contains different tools and resources for our dev and ci/cd processes

## Hetzner
### setHetznerMirror.sh
Checks if the executing system is located in a Hetzner datacenter by checking the availability of the hetzner apt mirror and sets the mirror if it is available.

## Proxmox
### setupDockerLXC.sh
To be run inside a LXC Container with enabled fuse, keyctl and nesting. Installs and configures FuseFS and installs docker-ce