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

set -e
set -x

if [[ "$RUNNER_OS" == "Linux" ]]; then
  # Install missing packages on Linux.
  #
  # NOTE: In order to get a musl-based static build, we run our automated
  # builds inside an Alpine Linux container, not directly on GitHub's Ubuntu
  # VMs.
  if repo-src/is-alpine.sh; then
    sudo apk update
    sudo apk upgrade
    sudo apk add \
      cmake \
      curl \
      diffutils \
      g++ \
      git \
      libvdpau-dev \
      linux-headers \
      make \
      nasm \
      patch \
      perl \
      pkgconfig \
      yasm
  else
    # This can be used by the developer on Ubuntu.  The builds may or may not
    # work portably on other platforms.
    sudo apt -y update
    sudo apt -y upgrade
    sudo apt -y install \
      clang \
      cmake \
      curl \
      g++ \
      git \
      libffmpeg-nvenc-dev \
      libva-dev \
      make \
      nasm \
      npm \
      pkg-config \
      wget \
      yasm
  fi

  # Use sudo in install commands on Linux.
  echo "SUDO=sudo" >> "$GITHUB_ENV"
elif [[ "$RUNNER_OS" == "macOS" ]]; then
  # Use homebrew to install missing packages on mac.
  brew install \
    md5sha1sum \
    nasm \
    yasm

  # Unlink pre-installed homebrew packages that conflict with our static
  # library builds below.  They are still installed, but will no longer be
  # symlinked into default library paths, and the ffmpeg build will not pick up
  # pre-installed shared libraries we don't want.  Only our static versions
  # will be used.  The list of preinstalled packages in the GitHub Actions
  # environment may change over time, so this list may need to change, as well.
  # Ignore errors if one of these is not installed.
  for i in \
    aom \
    lame \
    libvpx \
    libx11 \
    libxau \
    libxcb \
    libxdmcp \
    mbedtls \
    opus \
    opusfile \
    svt-av1 \
    x264 \
    x265 \
    xz \
  ; do brew unlink $i &>/dev/null || true; done

  # Use sudo in install commands on macOS.
  echo "SUDO=sudo" >> "$GITHUB_ENV"
elif [[ "$RUNNER_OS" == "Windows" ]]; then
  # Install msys packages we will need.
  #
  # NOTE: Add tools to this list if you see errors like
  # "shared_info::initialize: size of shared memory region changed".  The tools
  # reporting such errors need to be explicitly replaced by msys versions.  The
  # list of preinstalled packages in the GitHub Actions environment may change
  # over time, so this list may need to change, as well.
  #
  # NOTE: pkg-config specifically must be installed because of
  # https://github.com/actions/runner-images/issues/5459, in which there is a
  # conflicting version that GitHub will not remove.
  #
  # NOTE: mingw-w64-x86_64-gcc must be installed because of conflicting GCC
  # toolchains installed with Strawberry Perl, Git, and one more through
  # Chocolatey.  None of these build clean executables that only depend on
  # standard DLLs.
  pacman -Sy --noconfirm \
    diffutils \
    git \
    make \
    mingw-w64-x86_64-gcc \
    nasm \
    patch \
    pkg-config \
    yasm

  # Make sure that cmake generates makefiles and not ninja files.
  echo "CMAKE_GENERATOR=MSYS Makefiles" >> "$GITHUB_ENV"

  # Make sure that pkg-config searches the path where we will install things.
  echo "PKG_CONFIG_PATH=/usr/local/lib/pkgconfig" >> "$GITHUB_ENV"
fi
