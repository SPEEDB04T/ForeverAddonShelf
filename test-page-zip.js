// Checks the shelf page's "Download all" without a browser: runs the page's own buildZip() against the files
// build.ps1 wrote to site/, and compares every entry with the released source under addons/.
// Run after build.ps1:  node test-page-zip.js
const fs = require("fs");
const path = require("path");

const here = __dirname;
const site = path.join(here, "site");
const html = fs.readFileSync(path.join(site, "index.html"), "utf8");
const found = html.match(/async function buildZip\(addons\) \{[\s\S]*?\n  \}\n/);
if (!found) throw new Error("buildZip() not found in site/index.html");

const entries = new Map();
class JSZip {                       // stands in for the real library: keeps what the page hands it
  file(name, data) { entries.set(name, Buffer.from(data instanceof ArrayBuffer ? new Uint8Array(data) : data)); }
  generateAsync() { return Promise.resolve(null); }
}
const fetchLocal = async (file) => {
  const full = path.join(site, file);
  if (!fs.existsSync(full)) return { ok: false, status: 404 };
  const bytes = fs.readFileSync(full);
  return {
    ok: true, status: 200,
    text: async () => bytes.toString("utf8"),
    arrayBuffer: async () => bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength),
  };
};
const buildZip = new Function("JSZip", "fetch", found[0] + "\nreturn buildZip;")(JSZip, fetchLocal);

const walk = (dir, base = dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
  e.name.startsWith(".") ? [] : e.isDirectory() ? walk(path.join(dir, e.name), base)
    : [path.relative(base, path.join(dir, e.name)).replace(/\\/g, "/")]);

(async () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(site, "addons.json"), "utf8"));
  await buildZip(manifest.addons);
  let bad = 0, encoded = 0;
  const fail = (msg) => { bad++; console.log("FAIL: " + msg); };
  for (const a of manifest.addons) {
    const folder = path.join(here, "addons", a.id);
    const real = walk(folder);
    if (real.length !== a.files.length) fail(`${a.id}: ${a.files.length} files listed, ${real.length} in addons/${a.id}`);
    encoded += a.files.filter((f) => f.endsWith(".b64")).length;
    for (const rel of real) {
      const got = entries.get(a.id + "/" + rel);
      if (!got) fail(`${a.id}/${rel} is not in the zip`);
      else if (!got.equals(fs.readFileSync(path.join(folder, rel)))) fail(`${a.id}/${rel} differs from the released file`);
    }
  }
  const expected = manifest.addons.reduce((n, a) => n + a.files.length, 0);
  if (entries.size !== expected) fail(`the zip has ${entries.size} entries, the list has ${expected}`);
  console.log(`page zip: ${manifest.addons.length} addons, ${entries.size} files (${encoded} sent as base64), ${bad} failed`);
  process.exit(bad ? 1 : 0);
})();
