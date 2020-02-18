#!/bin/bash

die() {
    echo "$@" >&2
    exit 1
}

set -x

export CRYSTAL_VERSION=$(crystal eval "puts Crystal::VERSION")
export CRYSTAL_COMMIT=$(crystal eval "puts Crystal::BUILD_COMMIT")
export CRYSTAL_DIST=o
export DOCKERFILE=.travis/Dockerfile.$RPMVERSION

workdir=$(pwd)
if [[ $CRYSTAL_DIST == l ]]; then # legacy
    curl -LO https://github.com/lugia-kun/crystal-for-legacy-dist/releases/download/0.32.1-1/crystal-${CRYSTAL_VERSION}-1.sles11.x86_64.tar.xz || die "Legacy dist does not support nightly build"
    xz -dc crystal-${CRYSTAL_VERSION}-1.sles11.x86_64.tar.xz >$workdir/crystal.tar
else # official
    pushd /snap/crystal/current
    tar -cf $workdir/crystal.tar .
    popd
fi
trap "rm -f $workdir/crystal.tar" 0 1 2


id=$(git log -n1 --format=%H -- $DOCKERFILE)
tag=$RPMVERSION-crystal-$CRYSTAL_DIST-$CRYSTAL_VERSION-$CRYSTAL_RELEASE

docker pull lugiakun/crystal-rpm:$tag
image_pulled=$?
if [[ $image_pulled -eq 0 ]]; then
    image_id="$(docker run -it lugiakun/crystal-rpm:$tag sh -c 'echo -n ${COMMIT_ID}')"
fi
if [[ "$image_id" ==  "$id" ]]; then
    docker tag lugiakun/crystal-rpm:$tag $RPMVERSION
else
    docker build -t $RPMVERSION --target=$RPMVERSION --build-arg CRYSTAL_VERSION=${CRYSTAL_VERSION} --build-arg CRYSTAL_RELEASE=${CRYSTAL_RELEASE} --build-arg COMMIT_ID=$id -f ${DOCKERFILE} . || die "Failed to build ${tag}"
    if echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin; then
        if [[ -z "$image_id" ]] || [[ $(git log "$image_id..$id" | wc -l) -gt 0 ]]; then
            docker tag $RPMVERSION lugiakun/crystal-rpm:$tag
            docker push lugiakun/crystal-rpm:$tag
        fi
    fi
fi
