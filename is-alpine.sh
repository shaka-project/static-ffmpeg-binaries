#!/bin/sh

# Copyright 2024 Google LLC
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

# Returns 0 if this is Alpine Linux.

OS_ID=$(cat /etc/os-release | grep ^ID= | cut -f 2 -d =)
if [ "$OS_ID" = "alpine" -o "$OS_ID" = "NotpineForGHA" ]; then
  # It is Alpine or the modified version we have to trick GitHub.
  exit 0
fi

# It is not Alpine.
exit 1
