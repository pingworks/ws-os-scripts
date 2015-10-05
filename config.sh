OS_SSH_USER="ubuntu"
OS_CTRL="10.33.0.10"
EXEC="bash -c"
COOKBOOK_BASE="$HOME/workspace/cookbooks"
BASEDOMAIN="ws.pingworks.net"
OS_AUTH_URL=http://$OS_CTRL:5000/v2.0
COMPUTE_NODES="ctrl compute1 compute2"
DOCKER_BASE_IMG="pingworks/docker-ws-baseimg:0.2"
DOCKER_JKMASTER_IMG="pingworks/docker-ws-jkmaster:0.3"
DOCKER_JKSLAVE_IMG="pingworks/docker-ws-jkslave:0.3"
DOCKER_FRONTEND_IMG="pingworks/docker-ws-frontend:0.3"
DOCKER_BACKEND_IMG="pingworks/docker-ws-backend:0.3"
DEBUG=0
unset USER
