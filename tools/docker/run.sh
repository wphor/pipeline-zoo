#!/bin/bash -e
#
# Copyright (C) 2019-2020 Intel Corporation.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Platforms
declare -A PLATFORMS=(["DEFAULT"]=1 ["DGPU"]=3)
PLATFORM=DEFAULT

IMAGE=
VOLUME_MOUNT=
CAPADD=
DEVICES=
DEVICEGRP=
DEFAULT_IMAGE="dlstreamer-pipeline-zoo"
ENTRYPOINT=
ENTRYPOINT_ARGS=
PRIVILEGED=
NETWORK=
USER=
ATTACH=
INTERACTIVE="-it"
CPUSET_CPUS=
CPUSET_MEMS=

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SOURCE_DIR=$(dirname "$SCRIPT_DIR")
SOURCE_DIR=$(dirname "$SOURCE_DIR")
ENVIRONMENT=$(env | cut -f1 -d= | grep -E '_(proxy)$' | sed 's/^/-e / ' | tr '\n' ' ')
ENVIRONMENT+="-e DISPLAY "
WORKDIR=
MOUNTSRC=true
PRIVILEGED=true

get_options() {
    while :; do
        case $1 in
        -h | -\? | --help)
            show_help # Display a usage synopsis.
            exit
            ;;
	--platform)
            if [ "$2" ]; then
                PLATFORM=$2
                shift
            else
                error 'ERROR: "--platform" requires an argument.'
            fi
            ;;
	--cpuset-mems)
            if [ "$2" ]; then
                CPUSET_MEMS=$2
                shift
            else
                error 'ERROR: "--cpuset-mems" requires an argument.'
            fi
            ;;
	--cpuset-cpus)
            if [ "$2" ]; then
                CPUSET_CPUS=$2
                shift
            else
                error 'ERROR: "--cpuset-cpus" requires an argument.'
            fi
            ;;
        --image) # Takes an option argument; ensure it has been specified.
            if [ "$2" ]; then
                IMAGE=$2
                shift
            else
                error 'ERROR: "--image" requires a non-empty option argument.'
            fi
            ;;
        --user)
            if [ "$2" ]; then
                USER="--user $2"
                shift
            else
                error 'ERROR: "--user" requires a non-empty option argument.'
            fi
            ;;
        -e)
            if [ "$2" ]; then
                ENVIRONMENT+="-e $2 "
                shift
            else
                error 'ERROR: "-e" requires a non-empty option argument.'
            fi
            ;;
        --entrypoint-args)
            if [ "$2" ]; then
                ENTRYPOINT_ARGS+="$2 "
                shift
            else
                error 'ERROR: "--entrypoint-args" requires a non-empty option argument.'
            fi
            ;;
        -v)
            if [ "$2" ]; then
                VOLUME_MOUNT+="-v $2 "
                shift
            else
                error 'ERROR: "-v" requires a non-empty option argument.'
            fi
            ;;
        --name)
            if [ "$2" ]; then
                NAME=$2
                shift
            else
                error 'ERROR: "--name" requires a non-empty option argument.'
            fi
            ;;
        --network)
            if [ "$2" ]; then
                NETWORK="--network $2"
                shift
            else
                error 'ERROR: "--network" requires a non-empty option argument.'
            fi
            ;;
        --entrypoint)
            if [ "$2" ]; then
                ENTRYPOINT="--entrypoint $2"
                shift
            else
                error 'ERROR: "--entrypoint" requires a non-empty option argument.'
            fi
            ;;
        --workdir)
            if [ "$2" ]; then
                WORKDIR="--workdir $2"
                shift
            else
                error 'ERROR: "--workdir" requires a non-empty option argument.'
            fi
            ;;
        --mount-src)
            if [ "$2" ]; then
                MOUNTSRC="$2"
                shift
            else
                error 'ERROR: "--mount-src" requires a true/false argument'
            fi
            ;;  
        --privileged)
            if [ "$2" ]; then
                PRIVILEGED="$2"
                shift
            else
                error 'ERROR: "--privileged" requires a true/false argument'
            fi
            ;;
        --gpus)
            if [ "$2" = "all" ]; then
                GPUS_ALL+="--gpus all "
                shift
            else
                error 'ERROR: unknown option: ' $1 $2
            fi
            ;;
        --attach)
            ATTACH=TRUE
            ;;
        --non-interactive)
            INTERACTIVE="-t"
            ;;
        --) # End of all options.
            shift
            break
            ;;
        -?*)
        error 'ERROR: Unknown option: ' $1
            ;;
        ?*)
        error 'ERROR: Unknown option: ' $1
            ;;
        *) # Default case: No more options, so break out of the loop.
            break ;;
        esac

        shift
    done

    if [ ! -z "$PLATFORM" ]; then
        PLATFORM=${PLATFORM^^}
        if [[ ! -n "${PLATFORMS[$PLATFORM]}" ]]; then
            error 'ERROR: Unknown platform: ' $PLATFORM
        fi
    fi

    if [[ $PLATFORM =~ "DGPU" ]] ; then
        CAPADD="--cap-add SYS_ADMIN"
        DEVICE=${DEVICE:-/dev/dri/renderD128}
        DEVICE_GRP=$(ls -g $DEVICE | awk '{print $3}' | xargs getent group | awk -F: '{print $3}')
        ENVIRONMENT+=" -e DEVICE=$DEVICE"
        DEVICES="--device=$DEVICE"
        if [ -e /dev/dri/by-path ]; then BY_PATH="-v /dev/dri/by-path:/dev/dri/by-path"; fi
        DEVICEGRP="--group-add $DEVICE_GRP $BY_PATH"
    fi
    
    if [ "${PRIVILEGED,,}" == "true" ]; then
        PRIVILEGED="--privileged "
    else
        PRIVILEGED=""
    fi

    if [ -z "$IMAGE" ]; then
        IMAGE=$DEFAULT_IMAGE
        if [ ! -z "$PLATFORM" ] && [ $PLATFORM != 'DEFAULT' ]; then
            IMAGE+="-${PLATFORM,,}"
        fi
    fi

    if [ -z "$NAME" ]; then
        # Convert tag separator if exists
        NAME=${IMAGE//[\:]/_}
	NAME=${NAME//[\/]/_}
    fi

    if [[ "$GITHUB_TOKEN" ]]; then
        ENVIRONMENT+=" -e GITHUB_TOKEN=$GITHUB_TOKEN"
    fi

    if [ -f "$HOME/.netrc" ]; then
	VOLUME_MOUNT+="-v $HOME/.netrc:/root/.netrc "
    fi
}

show_options() {
    echo ""
    echo "Running Media Analytics Pipeline Zoo Image: '${IMAGE}'"
    echo "   Environment: '${ENVIRONMENT}'"
    echo "   Volume Mounts: '${VOLUME_MOUNT}'"
    echo "   Name: '${NAME}'"
    echo "   Network: '${NETWORK}'"
    echo "   Entrypoint: '${ENTRYPOINT}'"
    echo "   EntrypointArgs: '${ENTRYPOINT_ARGS}'"
    echo "   User: '${USER}'"
    echo "   workdir: '${WORKDIR}'"
    echo "   mount src: '${MOUNTSRC}'"
    echo "   privileged: '${PRIVILEGED}'"
    echo "   Attach: '${ATTACH}'"
    echo "   Interactive: '${INTERACTIVE}'"
    echo "   Platform: '${PLATFORM}'"
    echo ""
}

show_help() {
  echo "usage: run.sh" 
  echo "  [--image image]"
  echo "  [-v additional volume mount to pass to docker run]"
  echo "  [-e additional environment to pass to docker run]"
  echo "  [--entrypoint-args additional parameters to pass to entrypoint in docker run]"
  echo "  [--network name network to pass to docker run]"
  echo "  [--user name of user to pass to docker run]"
  echo "  [--name container name to pass to docker run]"
  echo "  [--attach attach to running container]"
  echo "  [--mount-src [true/false] mount pipeline-zoo source directory]"
  echo "  [--privileged [true/false] launch container in privileged mode]"
  echo "  [--workdir working directory to start with inside the container to docker run]"
  echo "  [--non-interactive run container without -i flag]"
  echo "  [--platform platform specific image]"
  echo "  [--gpus all]"
  exit 0
}

error() {
    printf '%s %s\n' "$1" "$2" >&2
    exit 1
}

get_options "$@"

if [ "${MOUNTSRC,,}" == "true"  ]; then
  VOLUME_MOUNT+="-v $SOURCE_DIR:/home/pipeline-zoo/ "
fi
VOLUME_MOUNT+="-v /tmp:/tmp "
VOLUME_MOUNT+="-v /var/tmp:/var/tmp "
VOLUME_MOUNT+="-v /dev:/dev "
VOLUME_MOUNT+="-v /lib/modules:/lib/modules "
VOLUME_MOUNT+="-v $HOME/.Xauthority:/root/.Xauthority "
mkdir -p $SOURCE_DIR/workspace
mkdir -p $SOURCE_DIR/workspace/.cl-cache

if [ -z "$NETWORK" ]; then
    NETWORK="--network=host";
fi

if [ ! -z "$CPUSET_MEMS" ]; then
    CPUSET_MEMS="--cpuset-mems=$CPUSET_MEMS";
fi

if [ ! -z "$CPUSET_CPUS" ]; then
    CPUSET_CPUS="--cpuset-cpus=$CPUSET_CPUS";
fi

if [ -z "$ENTRYPOINT" ]; then
    ENTRYPOINT="--entrypoint /bin/bash";
fi


show_options

if [ -z "$ATTACH" ]; then
    set -x
    docker run $INTERACTIVE $WORKDIR --rm $GPUS_ALL $ENVIRONMENT $VOLUME_MOUNT $CAPADD $DEVICES $DEVICEGRP $NETWORK $ENTRYPOINT $CPUSET_CPUS $CPUSET_MEMS --name ${NAME} ${PRIVILEGED} ${USER} $IMAGE ${ENTRYPOINT_ARGS}
     { set +x; } 2>/dev/null
else
    RUNNING_INSTANCE=$(docker ps -q --filter "name=$IMAGE")
    if [ ! -z "$RUNNING_INSTANCE" ]; then
        set -x
        docker attach $RUNNING_INSTANCE
        { set +x; } 2>/dev/null
    else
        error 'No Running Instance found'
    fi
fi
