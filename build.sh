#!/bin/bash
#
# build a pull request or use a local volume to build and test deis

# fail on any command exiting non-zero
set -eo pipefail

if [ "$USER" == 'root' ]; then
  echo "Please do not run this as root"
  exit 1
fi

# check for the required vagrant plugins
if ! vagrant plugin list | grep -q "vagrant-triggers"; then
  vagrant plugin install vagrant-triggers
fi

if ! vagrant plugin list | grep -q "vagrant-vbguest"; then
  vagrant plugin install vagrant-vbguest
fi

export PATH=$PATH:/usr/local/go/bin

export HOST_IPADDR=$(ifconfig $(ip route | grep default | head -1 | sed 's/\(.*dev \)\([a-z0-9]*\)\(.*\)/\2/g') | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1)

export REGISTRY_PORT=${REGISTRY_PORT:-5003}
export DEV_REGISTRY=${HOST_IPADDR}:${REGISTRY_PORT}

# database defaults.
export DATABASE_HOST=$HOST_IPADDR
export DATABASE_PORT=${DATABASE_PORT:-5432}
export DATABASE_USER=${DATABASE_USER:-deis}
export DATABASE_PASSWORD=${DATABASE_PASSWORD:-changeme123}

# download postgres
docker pull postgres:9.3

# download docker registry
docker pull registry:0.9.1

# download squid container to speed up the downloads
docker pull jpetazzo/squid-in-a-can

# run postgres db
POSTGRES=deis-postgres-test
docker inspect $POSTGRES >/dev/null 2>&1 && docker start $POSTGRES || \
  docker run --restart="always" \
    --name $POSTGRES \
    -e POSTGRES_USER=$DATABASE_USER \
    -e POSTGRES_PASSWORD=$DATABASE_PASSWORD \
    -p $DATABASE_PORT:5432 \
    -d postgres:9.3

# run squid
# docker inspect squid-data >/dev/null 2>&1 || \
#   docker run \
#     --name squid-data \
#     -v /var/cache/squid3 \
#     ubuntu-debootstrap:14.04 /bin/true

# SQUID_NAME=squid
# docker inspect "$SQUID_NAME" >/dev/null 2>&1 && docker start "$SQUID_NAME" || \
#   docker run --name "$SQUID_NAME" \
#     --restart="always" \
#     -e DISK_CACHE_SIZE:5120 \
#     -e MAX_CACHE_OBJECT:1024 \
#     --volumes-from=squid-data \
#     -d jpetazzo/squid-in-a-can

# export http_proxy="http://$HOST_IPADDR:3128"

# temporal build directory
BUILD=/tmp/$(date +%s)
mkdir -p "$BUILD"

# create a custom go location per build
export GOPATH="$BUILD-deis-go"
# go deis location
DEIS_GO="$GOPATH/src/github.com/deis"
mkdir -p "$DEIS_GO"
# delete current symlink
rm -rf "$DEIS_GO/deis"
ln -s "$BUILD" "$DEIS_GO/deis"

WHAT=$1

re='^[0-9]+$'
if ! [[ $WHAT =~ $re ]] ; then
  # check that the specified path exists
  echo ""
  echo "Building local copy located in $WHAT"
  echo ""
else
  echo ""
  echo "Building Pull Request $WHAT"
  echo ""
  SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
  git clone https://github.com/deis/deis "$BUILD"
  cp git-hack/git-config "$BUILD/.git/config"
  cd "$BUILD"
  git fetch origin
  git checkout pr/"$WHAT"
  # temporal local changes
  cp "$SCRIPT_DIR/changes/settings.py" "$BUILD/controller/deis/settings.py"
  cp "$SCRIPT_DIR/changes/Makefile" "$BUILD/Makefile"
  cp "$SCRIPT_DIR/changes/includes.mk" "$BUILD/includes.mk"
  git add includes.mk Makefile controller/deis/settings.py
  git status
  git commit -m "build"
  # end temporal hack
fi


make dev-registry

# wait for the registry
while ! curl --output /dev/null --silent --head --fail "http://$DEV_REGISTRY";
do
  sleep 1 && echo -n .;
done;

# run the integration tests
./tests/bin/test-integration.sh

echo "done"
