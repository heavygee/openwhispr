# Windows Build

This fork is set up with a manual GitHub Actions workflow for unsigned Windows artifacts:

1. Open the `Windows Artifact` workflow in GitHub Actions.
2. Run it manually from the `main` branch.
3. Download the `openwhispr-windows-unsigned` artifact from the completed run.

The workflow uses a native `windows-latest` runner, Node.js 24, the repo's existing `build:win` script, and disables release publishing plus Azure Trusted Signing. That keeps the fork build independent of upstream-only secrets like `GH_TOKEN`, `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, and `AZURE_CLIENT_SECRET`.

## Local Windows Build

From a Windows machine with Node.js 24+:

```powershell
npm ci
$env:CSC_IDENTITY_AUTO_DISCOVERY = "false"
node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync('electron-builder.json','utf8')); c.win={...c.win, azureSignOptions:null}; c.publish=null; fs.writeFileSync('electron-builder.unsigned.json', JSON.stringify(c,null,2));"
npm run build:win -- --publish never --config electron-builder.unsigned.json
```

Artifacts are written to `dist/`.

## Docker Notes

Docker/Wine can build many Electron Windows targets from Linux, but it is not the default path for this repo. OpenWhispr requires Node.js 24+ and ships native modules plus Windows helper binaries, while the commonly documented `electronuserland/builder:*wine` images currently focus on older Node tags. If a Docker experiment hits Node engine or native dependency rebuild failures, stop there and use the native Windows runner instead.

Use Docker only as an experiment for unsigned builds, not as the release path, unless the image is pinned to Node.js 24 and the resulting installer is tested on Windows.
