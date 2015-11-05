#!/bin/bash

SCRIPTDIR=$(dirname ${BASH_SOURCE[0]})
. $SCRIPTDIR/common.sh

OS_SSH_USER="ubuntu"
OS_CTRL="10.33.0.10"
EXEC="bash -c"
COOKBOOK_BASE="$HOME/workspace/cookbooks"
BASEDOMAIN="ws.net"
OS_AUTH_URL=http://$OS_CTRL:5000/v2.0
COMPUTE_NODES="ctrl compute0 compute1 compute2"
DOCKER_BASE_IMG="pingworks/docker-ws-baseimg:0.2"
DOCKER_JKMASTER_IMG="pingworks/docker-ws-jkmaster:0.4"
DOCKER_JKSLAVE_IMG="pingworks/docker-ws-jkslave:0.4"
DOCKER_FRONTEND_IMG="pingworks/docker-ws-frontend:0.3"
DOCKER_BACKEND_IMG="pingworks/docker-ws-backend:0.3"
DOCKER_APT_MIRROR_IMG="pingworks/apt-mirror:0.4"
DOCKER_GEM_MIRROR_IMG="pingworks/gem-mirror:0.3"
DOCKER_HUB_IMAGES="$DOCKER_BASE_IMG $DOCKER_APT_MIRROR_IMG $DOCKER_GEM_MIRROR_IMG"
IMAGES="$DOCKER_JKMASTER_IMG $DOCKER_JKSLAVE_IMG $DOCKER_FRONTEND_IMG $DOCKER_BACKEND_IMG"
DEBUG=0
PARALLEL=5
unset USER
