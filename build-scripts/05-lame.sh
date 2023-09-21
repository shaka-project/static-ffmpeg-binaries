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

version=$(repo-src/.github/workflows/get-version.sh lame)
curl -L -o lame-"$version".tar.gz https://sourceforge.net/projects/lame/files/lame/"$version"/lame-"$version".tar.gz/download
tar xzf lame-"$version".tar.gz
cd lame-"$version"

# Only build and install the library (--disable-front-end).  The
# frontend doesn't build on Windows, and we don't need it anyway.
# On Windows, somehow prefix defaults to / instead of /usr/local, but
# only on some projects.  No idea why that is the default on Windows,
# but --prefix=/usr/local fixes it.
./configure \
  --prefix=/usr/local \
  --disable-frontend \
  --enable-static \
  --disable-shared

make
$SUDO make install
