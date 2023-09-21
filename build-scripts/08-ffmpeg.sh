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

tag=$(repo-src/.github/workflows/get-version.sh ffmpeg)
git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git -b "$tag"
cd ffmpeg

# Set some OS-specific environment variables and flags.
if [[ "$RUNNER_OS" == "Linux" ]]; then
  export CFLAGS="-static"
  export LDFLAGS="-static"

  # Enable platform-specific hardware acceleration.
  PLATFORM_CONFIGURE_FLAGS="--enable-vdpau"
elif [[ "$RUNNER_OS" == "macOS" ]]; then
  export CFLAGS="-static"
  # You can't do a _truly_ static build on macOS except the kernel.
  # So don't set LDFLAGS.  See https://stackoverflow.com/a/3801032

  # Enable platform-specific hardware acceleration.
  PLATFORM_CONFIGURE_FLAGS="--enable-videotoolbox"

  # Disable x86 ASM on macOS.  It fails to build with an error about
  # how macho64 format can't contain 32-bit assembly.  I'm not sure
  # how else to resolve this, and from my searches, it appears that
  # others are not having this problem with ffmpeg.
  # TODO: Try building from master branch to see if this has been
  # resolved more recently than n4.4.
  PLATFORM_CONFIGURE_FLAGS="$PLATFORM_CONFIGURE_FLAGS --disable-x86asm --disable-inline-asm"
elif [[ "$RUNNER_OS" == "Windows" ]]; then
  # /usr/local/incude and /usr/local/lib are not in mingw's include
  # and linker paths by default, so add them.
  export CFLAGS="-static -I/usr/local/include"
  export LDFLAGS="-static -L/usr/local/lib"

  # Convince ffmpeg that we want to build for mingw64 (native
  # Windows), not msys (which involves some posix emulation).  Since
  # we're in an msys environment, ffmpeg reasonably assumes we're
  # building for that environment if we don't specify this.
  PLATFORM_CONFIGURE_FLAGS="--target-os=mingw64"
fi

./configure \
  --pkg-config-flags="--static" \
  --disable-ffplay \
  --enable-libvpx \
  --enable-libaom \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-mbedtls \
  --enable-runtime-cpudetect \
  --enable-gpl \
  --enable-version3 \
  --enable-static \
  $PLATFORM_CONFIGURE_FLAGS

make
# No "make install" for ffmpeg.
