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

tag=$(repo-src/get-version.sh libvpx)
git clone --depth 1 https://chromium.googlesource.com/webm/libvpx -b "$tag"
cd libvpx

# NOTE: disabling unit tests and examples significantly reduces build
# time (by 80% as tested on a Jetson Nano)
./configure \
  --enable-vp8 \
  --enable-vp9 \
  --enable-runtime-cpu-detect \
  --disable-unit-tests \
  --disable-examples \
  --enable-static \
  --disable-shared

make
$SUDO make install
