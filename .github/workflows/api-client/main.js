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
const path = require('path');
const { Octokit } = require('@octokit/core');

const repo = process.env['GITHUB_REPOSITORY'];

const octokit = new Octokit({
  auth: process.env['GITHUB_TOKEN'],
});

const command = process.argv[2];
const args = process.argv.slice(3);


const COMMAND_MAP = {
  'draft-release': draftRelease,
  'upload-all-assets': uploadAllAssets,
  'upload-asset': uploadAsset,
  'download-all-assets': downloadAllAssets,
  'publish-release': publishRelease,
  'update-release-body': updateReleaseBody,
};


const method = COMMAND_MAP[command];
if (!method) {
  throw new Error(`Unknown command "${command}"`);
}

(async () => {
  const response = await method(...args);
  // If there's a return value, print it.
  if (response) {
    console.log(response);
  }
})();


async function repoApiCall(method, apiPath, data) {
  const url = `${method} /repos/${repo}${apiPath}`;
  const response = await octokit.request(url, data);
  return response.data;
}

async function draftRelease(tagName) {
  // Turns "refs/tags/foo" into "foo".
  tagName = tagName.split('/').pop();

  const response = await repoApiCall('POST', '/releases', {
    tag_name: tagName,
    name: tagName,
    draft: true,
  });

  return response.id;
}

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
  });
}

async function uploadAllAssets(releaseId, folderPath) {
  const folderContents = await fs.promises.readdir(folderPath);
  for (const assetFilename of folderContents) {
    const assetPath = path.join(folderPath, assetFilename);
    await uploadAsset(releaseId, assetPath);
  }
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
    const assetPath = path.join(outputPath, asset.name);
    const outputStream = fs.createWriteSteam(assetPath);

    await new Promise((resolve, reject) => {
      const request = https.request(asset.browser_download_url, (response) => {
        response.pipe(outputStream);
      });
      outputStream.on('finish', resolve);
      request.on('error', reject);
    });
  }
}

async function publishRelease(releaseId) {
  await repoApiCall('PATCH', `/releases/${releaseId}`, { draft: false });
}

async function updateReleaseBody(releaseId, body) {
  await repoApiCall('PATCH', `/releases/${releaseId}`, { body });
}
