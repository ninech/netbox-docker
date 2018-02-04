#!/bin/bash

ORIGINAL_GITHUB_REPO="digitalocean/netbox"
GITHUB_REPO="${GITHUB_REPO-$ORIGINAL_GITHUB_REPO}"
URL_RELEASES="https://api.github.com/repos/${GITHUB_REPO}/releases"

JQ_LATEST="group_by(.prerelease) | .[] | sort_by(.published_at) | reverse | .[0] | select(.prerelease==${PRERELEASE-false}) | .tag_name"

CURL_OPTS="-s"
CURL="curl ${CURL_OPTS}"

VERSION=$($CURL "${URL_RELEASES}" | jq -r "${JQ_LATEST}")

# Check if the prerelease version is actually higher than stable version
if [ "${PRERELEASE}" == "true" ]; then
  JQ_STABLE="group_by(.prerelease) | .[] | sort_by(.published_at) | reverse | .[0] | select(.prerelease==false) | .tag_name"
  STABLE_VERSION=$(curl $CURL_OPTS "${URL_RELEASES}" | jq -r "${JQ_STABLE}")

  MAJOR_STABLE=$(expr match "${STABLE_VERSION}" 'v\([0-9]\+\)')
  MINOR_STABLE=$(expr match "${STABLE_VERSION}" 'v[0-9]\+\.\([0-9]\+\)')
  MAJOR_UNSTABLE=$(expr match "${VERSION}" 'v\([0-9]\+\)')
  MINOR_UNSTABLE=$(expr match "${VERSION}" 'v[0-9]\+\.\([0-9]\+\)')

  if ( [ "$MAJOR_STABLE" -eq "$MAJOR_UNSTABLE" ] && [ "$MINOR_STABLE" -ge "$MINOR_UNSTABLE" ] ) \
     || [ "$MAJOR_STABLE" -gt "$MAJOR_UNSTABLE" ]; then
    echo "Latest unstable version ('$VERSION') is not higher than the latest stable version ('$STABLE_VERSION')."
    exit 0
  fi
fi

# Check if that version is not already available on docker hub:
ORIGINAL_DOCKERHUB_REPO="ninech/netbox"
DOCKERHUB_REPO="${DOCKERHUB_REPO-$ORIGINAL_DOCKERHUB_REPO}"
URL_DOCKERHUB_TOKEN="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${DOCKERHUB_REPO}:pull"
BEARER_TOKEN="$($CURL "${URL_DOCKERHUB_TOKEN}" | jq -r .token)"

URL_DOCKERHUB_TAG="https://registry.hub.docker.com/v2/${DOCKERHUB_REPO}/tags/list"
AUTHORIZATION_HEADER="Authorization: Bearer ${BEARER_TOKEN}"
ALREADY_BUILT="$($CURL -H "${AUTHORIZATION_HEADER}" "${URL_DOCKERHUB_TAG}" | jq -e ".tags | any(.==\"${VERSION}\")")"

if [ "$ALREADY_BUILT" == "false" ]; then
  ./build.sh "${VERSION}" $@
else
  echo "✅ ${VERSION} already exists on https://hub.docker.com/r/${DOCKERHUB_REPO}"
fi
