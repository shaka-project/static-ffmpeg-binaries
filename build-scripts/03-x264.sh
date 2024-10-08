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

tag=$(repo-src/get-version.sh x264)
git clone https://code.videolan.org/videolan/x264.git
cd x264
git checkout "$tag"

# NOTE: disable OpenCL-based features because it uses dlopen and can interfere
# with static builds.
./configure \
  --disable-opencl \
  --enable-static

# Only build and install the static library.
make libx264.a
$SUDO make install-lib-static
