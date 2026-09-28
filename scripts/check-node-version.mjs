const major = Number.parseInt(process.versions.node.split('.')[0] ?? '', 10);
if (major !== 22) {
  console.error(`NODE_VERSION_BLOCKED expected=22 actual=${process.versions.node}`);
  process.exit(1);
}
console.log(`NODE_VERSION_OK version=${process.versions.node}`);
