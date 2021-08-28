// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// A script to communicate with the GitHub API to perform certain actions in
// the workflow.

const fs = require('fs');
const https = require('https');
const path = require('path');

// octokit is the official API client of GitHub.
const { Octokit } = require('@octokit/core');

const repo = process.env['GITHUB_REPOSITORY'];

const octokit = new Octokit({
  auth: process.env['GITHUB_TOKEN'],
});

const COMMAND_MAP = {};

const MAX_REDIRECTS = 3;


// Convert a camelCase name to kebab-case.
function camelCaseToKebabCase(name) {
  // Split the camelCase name into parts with a zero-length lookahead regex on
  // any capital letter.  Something like "methodName" should be split into
  // ["method", "Name"].
  const nameParts = name.split(/(?=[A-Z])/);

  // Convert those parts into a kebab-case name.
  return nameParts.map(part => part.toLowerCase()).join('-');
}

// Register a method that the user can invoke on the command-line.  We use
// (cheap) introspection to find the argument names, so that we can
// automatically document usage of each command without worrying about the docs
// getting out of sync with the code.
function registerCommand(method) {
  const methodName = method.name;
  const commandName = camelCaseToKebabCase(methodName);

  // Hack out the arguments from the stringified function.  This is terrible
  // and will not work in the general case of all JavaScript, but it does work
  // here.  (Don't be like me.)
  const firstLine = method.toString().split('\n')[0];
  const argString = firstLine.split('(')[1].split(')')[0];
  const camelArgs = argString.replace(/\s+/g, '').split(',');
  const args = camelArgs.map(camelCaseToKebabCase);

  COMMAND_MAP[commandName] = {
    commandName,
    method,
    args,
  };
}

// A helper function to make calls to the GitHub Repo API.
async function repoApiCall(method, apiPath, data, upload=false) {
  const url = `${method} /repos/${repo}${apiPath}`;

  // Clone the "data" passed in.
  const options = Object.assign({}, data);

  // If we're uploading, that goes to a different API endpoint.
  if (upload) {
    options.baseUrl = 'https://uploads.github.com';
  }

  const response = await octokit.request(url, options);
  return response.data;
}


async function draftRelease(tagName) {
  // Turns "refs/tags/foo" into "foo".
  tagName = tagName.replace('refs/tags/', '');

  const response = await repoApiCall('POST', '/releases', {
    tag_name: tagName,
    name: tagName,
    draft: true,
  });

  return response.id;
}
registerCommand(draftRelease);

async function uploadAsset(releaseId, assetPath) {
  const baseName = path.basename(assetPath);
  const data = await fs.promises.readFile(assetPath);

  const apiPath = `/releases/${releaseId}/assets?name=${baseName}`;
  await repoApiCall('POST', apiPath, {
    headers: {
      'content-type': 'application/octet-stream',
      'content-length': data.length,
    },
    data,
  }, /* upload= */ true);
}
// Not registered as an independent command.

async function uploadAllAssets(releaseId, folderPath) {
  const folderContents = await fs.promises.readdir(folderPath);
  for (const assetFilename of folderContents) {
    const assetPath = path.join(folderPath, assetFilename);
    await uploadAsset(releaseId, assetPath);
  }
}
registerCommand(uploadAllAssets);

// A helper function that will fetch via HTTPS and follow redirects.
function fetchViaHttps(url, outputStream, redirectCount=0) {
  if (redirectCount > MAX_REDIRECTS) {
    throw new Error('Too many redirects!');
  }

  return new Promise((resolve, reject) => {
    const request = https.get(url, (response) => {
      if (response.statusCode == 301 || response.statusCode == 302) {
        // Handle HTTP redirects.
        const newUrl = response.headers.location;

        resolve(fetchViaHttps(newUrl, outputStream, redirectCount + 1));
      } else if (response.statusCode == 200) {
        response.pipe(outputStream);
        outputStream.on('finish', resolve);
      } else {
        reject(new Error(`Bad HTTP status code: ${response.statusCode}`));
      }
    });
    request.on('error', reject);
  });
}

async function downloadAllAssets(releaseId, outputPath) {
  // If the output path does not exist, create it.
  try {
    await fs.promises.stat(outputPath);
  } catch (error) {
    await fs.promises.mkdir(outputPath);
  }

  const apiPath = `/releases/${releaseId}/assets`;
  const assetList = await repoApiCall('GET', apiPath);
  for (const asset of assetList) {
    const url = asset.browser_download_url;
    const assetPath = path.join(outputPath, asset.name);
    const outputStream = fs.createWriteStream(assetPath);

    console.log(`Fetching ${url} to ${assetPath}`);
    await fetchViaHttps(url, outputStream);
  }
}
registerCommand(downloadAllAssets);

async function publishRelease(releaseId) {
  await repoApiCall('PATCH', `/releases/${releaseId}`, { draft: false });
}
registerCommand(publishRelease);

async function updateReleaseBody(releaseId, body) {
  // NOTE: If you update the release body without specifying tag_name, it gets
  // reset, resulting in a new tag being created with an auto-generated name
  // like "untagged-SHA1".  So we need to fetch the existing name before we
  // update the body, and we need to specify it here.  This is not mentioned in
  // GitHub's docs, and may be a bug on their end.
  const release = await getRelease(releaseId);
  await repoApiCall('PATCH', `/releases/${releaseId}`, {
    body,
    tag_name: release.tag_name,
  });
}
registerCommand(updateReleaseBody);

async function getRelease(releaseId) {
  return await repoApiCall('GET', `/releases/${releaseId}`);
}
registerCommand(getRelease);


// We expect a command and arguments.
const commandName = process.argv[2];
const args = process.argv.slice(3);
const command = COMMAND_MAP[commandName];
let okay = true;

if (!commandName) {
  console.error('No command selected!');
  okay = false;
} else if (!command) {
  console.error(`Unknown command: ${commandName}`);
  okay = false;
} else if (args.length != command.args.length) {
  console.error(`Wrong number of arguments for command: ${commandName}`);
  okay = false;
}

// If something is wrong with the way the script was called, print usage
// information.  The list of commands and their arguments are gleaned from
// COMMAND_MAP, which was populated by registerCommand() and introspection of
// the command functions.
if (!okay) {
  console.error('');
  console.error('Usage:');
  const thisScript = path.basename(process.argv[1]);

  for (possibleCommand of Object.values(COMMAND_MAP)) {
    console.error(
        '  ',
        thisScript,
        possibleCommand.commandName,
        ...possibleCommand.args.map(arg => `<${arg}>`));
  }
  process.exit(1);
}

// Run the command with the given arguments.
(async () => {
  let response;

  try {
    response = await command.method(...args);
  } catch (error) {
    console.error('Command failed!');
    console.error('');
    console.error(error);
    process.exit(1);
  }

  // If there's a return value, print it.
  if (response) {
    console.log(response);
  }
})();
