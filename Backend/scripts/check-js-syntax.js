const { execFileSync } = require('child_process');
const { readdirSync, statSync } = require('fs');
const { join, relative } = require('path');

const root = process.cwd();
const ignoredDirectories = new Set(['node_modules', '.git', 'validation-runs']);
const files = [];

function collectJavaScriptFiles(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!ignoredDirectories.has(entry.name)) {
        collectJavaScriptFiles(join(directory, entry.name));
      }
      continue;
    }

    if (entry.isFile() && entry.name.endsWith('.js')) {
      const fullPath = join(directory, entry.name);
      if (statSync(fullPath).size > 0) {
        files.push(fullPath);
      }
    }
  }
}

collectJavaScriptFiles(root);

for (const file of files) {
  execFileSync(process.execPath, ['--check', file], { stdio: 'inherit' });
}

console.log(`Checked syntax for ${files.length} JavaScript files.`);
