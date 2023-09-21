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

version=$(repo-src/.github/workflows/get-version.sh opus)
curl -LO https://archive.mozilla.org/pub/opus/opus-"$version".tar.gz
tar xzf opus-"$version".tar.gz
cd opus-"$version"

# On Windows, we can't link later if we build with -D_FORTIFY_SOURCE
# now.  But there is no configure option for this, so we edit the
# configure script instead.
sed -e 's/-D_FORTIFY_SOURCE=2//' -i.bk configure

# On Windows, somehow prefix defaults to / instead of /usr/local, but
# only on some projects.  No idea why that is the default on Windows,
# but --prefix=/usr/local fixes it.
# On Windows, we also need to disable-stack-protector.
./configure \
  --prefix=/usr/local \
  --disable-extra-programs \
  --disable-stack-protector \
  --enable-static \
  --disable-shared

make
$SUDO make install

# The pkgconfig linker flags for static opus don't work when ffmpeg
# checks for opus in configure.  Linking libm after libopus fixes it.
$SUDO sed -e 's/-lopus/-lopus -lm/' -i.bk /usr/local/lib/pkgconfig/opus.pc
