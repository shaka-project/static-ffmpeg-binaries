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

# Pull a tag or version number from versions.txt.

# Get the directory this script is in.
dir=$(dirname "$0")
# Get the key we want to look for in versions.txt.
# This is the first (and only) argument to the script.
key="$1"

# 1. "cat" will output the text file to stdout.
# 2. "grep" will filter for a line that begins with the desired key,
#    and only send matching lines to stdout.
#    ("^" is the regex character for "beginning of line")
# 3. "sed" will transform the output of grep by removing everything up to
#    and including the colon and space characters, leaving only the value
#    as output to stdout.
cat "$dir"/versions.txt | grep "^$key:" | sed -e 's/.*: //'
