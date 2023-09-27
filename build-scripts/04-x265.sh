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

tag=$(repo-src/get-version.sh x265)
git clone --depth 1 https://bitbucket.org/multicoreware/x265_git.git -b "$tag"
cd x265_git/build

# NOTE: without CMAKE_INSTALL_PREFIX on Windows, files are installed
# to c:\Program Files.
cmake ../source \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DENABLE_SHARED=OFF \
  -DENABLE_CLI=OFF

make
$SUDO make install

# This adjustment to the x265 linker flags is needed, at least on
# arm, to successfully link against it statically.  (-lgcc_s not
# found (or needed), and -lpthread missing)
$SUDO sed -e 's/-lgcc_s -lgcc -lgcc_s -lgcc/-lpthread -lgcc/' -i.bk /usr/local/lib/pkgconfig/x265.pc
