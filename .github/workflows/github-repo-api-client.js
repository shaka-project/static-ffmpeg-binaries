const { Octokit } = require('@octokit/action');
const octokit = new Octokit();
(async () => {
  const response = await octokit.request("GET /repos/{owner}/{repo}/releases", {
    owner: 'joeyparrish',
    repo: 'static-ffmpeg-binaries',
  });
  console.log(response);
})();
