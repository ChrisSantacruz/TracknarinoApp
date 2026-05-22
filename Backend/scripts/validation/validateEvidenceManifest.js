const { validateEvidenceManifest } = require('../../release/evidenceManifestValidator');

function readArgs() {
  const args = process.argv.slice(2);
  const options = {
    manifest: process.env.RELEASE_EVIDENCE_MANIFEST_PATH,
  };

  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === '--manifest') options.manifest = args[index + 1];
  }
  return options;
}

async function main() {
  const options = readArgs();
  const result = await validateEvidenceManifest(options.manifest);
  console.log(JSON.stringify(result, null, 2));
  if (!result.passed) {
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(`Evidence manifest validation failed: ${error.message}`);
  process.exit(1);
});
