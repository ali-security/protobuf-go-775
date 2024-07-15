#!/bin/bash
# Copyright 2019 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

cd "$(git rev-parse --show-toplevel)"

VERSION="v1.30.0-sp1"
SEMVER_REGEX='^v\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\)\([.a-zA-Z0-9A-Z-]*\)$'
if ! [[ -z $(echo $VERSION | sed -e "s/$SEMVER_REGEX//") ]]; then
	echo
	echo "invalid: must be a semver string"
	exit 1
fi
VERSION_MAJOR=$(echo $VERSION | sed -e "s/$SEMVER_REGEX/\1/")
VERSION_MINOR=$(echo $VERSION | sed -e "s/$SEMVER_REGEX/\2/")
VERSION_PATCH=$(echo $VERSION | sed -e "s/$SEMVER_REGEX/\3/")
VERSION_PRERELEASE=$(echo $VERSION | sed -e "s/$SEMVER_REGEX/\4/")
VERSION_PRERELEASE=${VERSION_PRERELEASE#"-"} # trim possible leading dash

function version_string() {
	VERSION_STRING="v${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}"
	if ! [[ -z $VERSION_PRERELEASE ]]; then
		VERSION_STRING="${VERSION_STRING}-${VERSION_PRERELEASE}"
	fi
	echo $VERSION_STRING
}

echo "Release version: $(version_string)"

echo
echo "Preparing changes to release $(version_string)."
echo

set -e

# Create commit for actual release.
INPLACE='-i ""' # BSD version of sed expects argument after -i
if [[ "$(sed --version)" == *"GNU"* ]]; then
	INPLACE="-i" # GNU version of sed does not expect argument after -i
fi
sed $INPLACE -e "s/\(Minor *= *\)[0-9]*/\1$VERSION_MINOR/" internal/version/version.go
sed $INPLACE -e "s/\(Patch *= *\)[0-9]*/\1$VERSION_PATCH/" internal/version/version.go
sed $INPLACE -e "s/\(PreRelease *= *\)\"[^\"]*\"/\1\"$VERSION_PRERELEASE\"/" internal/version/version.go
if ! [[ -z $GEN_VERSION ]]; then
	sed $INPLACE -e "s/\(GenVersion *= *\)[0-9]*/\1$GEN_VERSION/" runtime/protoimpl/version.go
fi
if ! [[ -z $MIN_VERSION ]]; then
	sed $INPLACE -e "s/\(MinVersion *= *\)[0-9]*/\1$MIN_VERSION/" runtime/protoimpl/version.go
fi
git commit -a -m "all: release $(version_string)"

# Build release binaries.
go test -mod=vendor -timeout=60m -count=1 integration_test.go "$@" -buildRelease
