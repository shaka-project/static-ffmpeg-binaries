#!/bin/bash

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Build everything, assuming we're inside an Ubuntu container.  This is useful
# for quick automated builds and for testing build script changes.

# Build with:
#   rm -rf build
#   docker run --rm -v $(pwd):/src -w /src ubuntu:24.04 /src/build.sh
# Build outputs are:
#   build/ffmpeg/ffmpeg
#   build/ffmpeg/ffprobe

# Fail on error
set -e
# Show commands as they are run
set -x

if [ ! -e build-scripts ]; then
  echo "Must be run from inside the static-ffmpeg-binaries repo." 1>&2
  exit 1
fi

# If run as root in a container, change to the ubuntu user.  This script only
# supports Ubuntu as a container, for simplicity.
if [[ $(id -u) == "0" ]]; then
  # If we're on Ubuntu before 24.04, there's no default "ubuntu" user.
  # This maps these older versions to the starting state of 24.04+.
  groupadd -g 1000 ubuntu || true
  useradd -u 1000 -g 1000 -m -d /home/ubuntu ubuntu || true

  # Sudo is needed by the first build script, and vim is for interactive
  # debugging and editing in the container.
  apt -y update && apt -y upgrade && apt -y install vim sudo

  # Make sudo work without a password.
  echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

  # Create build/ and make it owned by ubuntu inside this Docker container, not
  # the current user outside Docker.
  rm -rf build
  mkdir build
  chown ubuntu build

  if [ -z "$GITHUB_ENV" ]; then
    # Running outside of GitHub Actions?  Set these important variables.
    export GITHUB_ENV=/tmp/github.env
    export SUDO=sudo
    export RUNNER_OS=Linux
  fi

  # Preserve the environment (-p), which contains important variables like
  # RUNNER_OS, etc.
  exec su -p ubuntu "$0" "$@"
fi

# If we are running outside a container, we may not have hit the "root" branch
# above.  Create the build/ folder if it doesn't exist.
mkdir -p build

# Set up the same symlink we get from our GitHub workflow, expected by the
# build scripts.
cd build
ln -s ../ repo-src

# Run each build script in order.
for SCRIPT in ./repo-src/build-scripts/*; do
  "$SCRIPT" || exit 1
done
