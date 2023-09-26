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

tag=$(repo-src/.github/workflows/get-version.sh aom)
git clone --depth 1 https://aomedia.googlesource.com/aom/ -b "$tag"

# AOM insists on being built out-of-tree.
mkdir aom_build
cd aom_build

# NOTE: without CMAKE_INSTALL_PREFIX on Windows, files are installed
# to c:\Program Files.
# NOTE: without CMAKE_INSTALL_LIBDIR on Linux, pkgconfig and static
# libs are installed to /usr/local/lib/x86_64-linux-gnu/ instead of
# /usr/local/lib/.
cmake ../aom \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_DOCS=OFF \
  -DENABLE_EXAMPLES=OFF \
  -DENABLE_TESTS=OFF \
  -DENABLE_TESTDATA=OFF \
  -DENABLE_TOOLS=OFF \
  -DCONFIG_RUNTIME_CPU_DETECT=1 \
  -DCONFIG_SHARED=0

make
$SUDO make install

# This adjustment to the aom linker flags is needed, at least on
# arm, to successfully link against it statically.  (-lm missing)
$SUDO sed -e 's/-laom/-laom -lm/' -i.bk /usr/local/lib/pkgconfig/aom.pc
