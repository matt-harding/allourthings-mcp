import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { execFileSync } from "node:child_process";
import process from "node:process";

const repositoryRoot = resolve(import.meta.dirname, "..");
const extensionRoot = join(repositoryRoot, "packages", "claude-extension");
const serverRoot = join(repositoryRoot, "packages", "mcp-server");
const stageRoot = join(extensionRoot, "build", "allourthings");
const releaseRoot = join(extensionRoot, "release");
const coreRoot = join(repositoryRoot, "node_modules", "@allourthings", "core");
const iconSource = resolve(repositoryRoot, "..", "allourthings-website", "public", "allourthings-icon-512.png");

function run(command, args, cwd = repositoryRoot) {
  execFileSync(command, args, { cwd, stdio: "inherit" });
}

function copy(source, destination) {
  mkdirSync(dirname(destination), { recursive: true });
  cpSync(source, destination, { recursive: true });
}

function validateStage() {
  const manifestPath = join(stageRoot, "manifest.json");
  const parsed = JSON.parse(readFileSync(manifestPath, "utf8"));
  const requiredManifestValues = [
    ["manifest_version", "0.4"],
    ["name", "allourthings"],
    ["version", version],
    ["server.type", "node"],
    ["server.entry_point", "server/dist/index.js"],
  ];
  for (const [path, expected] of requiredManifestValues) {
    const actual = path.split(".").reduce((value, key) => value?.[key], parsed);
    if (actual !== expected) throw new Error(`Invalid manifest ${path}: expected ${expected}`);
  }
  if (parsed.user_config?.data_dir?.type !== "directory" || !parsed.user_config.data_dir.required) {
    throw new Error("The extension manifest must require a vault directory picker.");
  }
  if (!parsed.compatibility?.platforms?.includes("darwin")) {
    throw new Error("The extension manifest must be limited to macOS.");
  }
  for (const relativePath of [
    "server/dist/index.js",
    "server/package.json",
    "server/node_modules/@allourthings/core/index.js",
    "server/node_modules/@allourthings/core/allourthings-core.darwin-arm64.node",
    "assets/allourthings-icon-512.png",
  ]) {
    if (!existsSync(join(stageRoot, relativePath))) throw new Error(`Missing staged file: ${relativePath}`);
  }
}

const serverPackage = JSON.parse(readFileSync(join(serverRoot, "package.json"), "utf8"));
const version = serverPackage.version;
const requiredCoreFiles = [
  "index.js",
  "package.json",
  "LICENSE",
  "allourthings-core.darwin-arm64.node",
];

if (process.arch !== "arm64" || process.platform !== "darwin") {
  throw new Error("The Claude extension release build must run on an Apple Silicon Mac.");
}

for (const file of requiredCoreFiles) {
  if (!existsSync(join(coreRoot, file))) {
    throw new Error(`Missing bundled native dependency: ${join(coreRoot, file)}`);
  }
}

if (!existsSync(iconSource)) {
  throw new Error(`Missing extension icon: ${iconSource}`);
}

run("bun", ["run", "build"], serverRoot);

rmSync(stageRoot, { recursive: true, force: true });
mkdirSync(stageRoot, { recursive: true });

const manifest = readFileSync(join(extensionRoot, "manifest.template.json"), "utf8")
  .replaceAll("__VERSION__", version);
writeFileSync(join(stageRoot, "manifest.json"), manifest);
writeFileSync(
  join(stageRoot, "package.json"),
  `${JSON.stringify({ name: "allourthings-claude-extension", version, private: true, type: "module" }, null, 2)}\n`
);

copy(join(serverRoot, "dist"), join(stageRoot, "server", "dist"));
copy(join(serverRoot, "package.json"), join(stageRoot, "server", "package.json"));
copy(iconSource, join(stageRoot, "assets", "allourthings-icon-512.png"));
for (const file of requiredCoreFiles) {
  copy(join(coreRoot, file), join(stageRoot, "server", "node_modules", "@allourthings", "core", file));
}

mkdirSync(releaseRoot, { recursive: true });
const archive = join(releaseRoot, `allourthings-claude-extension-${version}-darwin-arm64.mcpb`);
rmSync(archive, { force: true });
validateStage();
run("zip", ["-q", "-r", "-9", archive, "."], stageRoot);
run("unzip", ["-t", archive]);

console.log(`Built ${archive}`);
