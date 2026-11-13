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
const targets = {
  "darwin-arm64": {
    hosts: ["darwin-arm64"],
    platforms: ["darwin"],
    coreAddons: ["allourthings-core.darwin-arm64.node"],
  },
  "win32-x64": {
    hosts: ["win32-x64"],
    platforms: ["win32"],
    coreAddons: ["allourthings-core.win32-x64-msvc.node"],
  },
  universal: {
    hosts: ["darwin-arm64", "win32-x64"],
    platforms: ["darwin", "win32"],
    coreAddons: [
      "allourthings-core.darwin-arm64.node",
      "allourthings-core.win32-x64-msvc.node",
    ],
  },
};

function run(command, args, cwd = repositoryRoot) {
  execFileSync(command, args, { cwd, stdio: "inherit" });
}

function copy(source, destination) {
  mkdirSync(dirname(destination), { recursive: true });
  cpSync(source, destination, { recursive: true });
}

function resolveTarget() {
  const targetIndex = process.argv.indexOf("--target");
  const host = `${process.platform}-${process.arch}`;
  const name = targetIndex === -1 ? host : process.argv[targetIndex + 1];
  if (!name || !(name in targets)) {
    throw new Error("Supported targets are darwin-arm64, win32-x64, and universal.");
  }
  const target = targets[name];
  if (!target.hosts.includes(host)) {
    throw new Error(`Target ${name} must be built on one of: ${target.hosts.join(", ")}.`);
  }
  return { name, ...target };
}

const target = resolveTarget();

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
  if (JSON.stringify(parsed.compatibility?.platforms) !== JSON.stringify(target.platforms)) {
    throw new Error(`The extension manifest must support: ${target.platforms.join(", ")}.`);
  }
  for (const relativePath of [
    "server/dist/index.js",
    "server/package.json",
    "server/node_modules/@allourthings/core/index.js",
    ...target.coreAddons.map((addon) => `server/node_modules/@allourthings/core/${addon}`),
  ]) {
    if (!existsSync(join(stageRoot, relativePath))) throw new Error(`Missing staged file: ${relativePath}`);
  }
}

function packArchive(archive) {
  if (process.platform === "win32") {
    const verificationRoot = join(extensionRoot, "build", "archive-contents");
    rmSync(verificationRoot, { recursive: true, force: true });
    const powershell = [
      "$ErrorActionPreference = 'Stop'",
      `Compress-Archive -Path '${join(stageRoot, "*")}' -DestinationPath '${archive}' -CompressionLevel Optimal -Force`,
      `Expand-Archive -Path '${archive}' -DestinationPath '${verificationRoot}' -Force`,
    ].join("; ");
    run("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", powershell]);
    if (!existsSync(join(verificationRoot, "manifest.json"))) {
      throw new Error("Windows archive verification failed: manifest.json is missing.");
    }
    return;
  }
  run("zip", ["-q", "-r", "-9", archive, "."], stageRoot);
  run("unzip", ["-t", archive]);
}

const serverPackage = JSON.parse(readFileSync(join(serverRoot, "package.json"), "utf8"));
const version = serverPackage.version;
const requiredCoreFiles = [
  "index.js",
  "package.json",
  "LICENSE",
  ...target.coreAddons,
];

for (const file of requiredCoreFiles) {
  if (!existsSync(join(coreRoot, file))) {
    throw new Error(`Missing bundled native dependency: ${join(coreRoot, file)}`);
  }
}

run("bun", ["run", "build"], serverRoot);

rmSync(stageRoot, { recursive: true, force: true });
mkdirSync(stageRoot, { recursive: true });

const manifest = readFileSync(join(extensionRoot, "manifest.template.json"), "utf8")
  .replaceAll("__VERSION__", version)
  .replaceAll("__PLATFORMS__", JSON.stringify(target.platforms));
writeFileSync(join(stageRoot, "manifest.json"), manifest);
writeFileSync(
  join(stageRoot, "package.json"),
  `${JSON.stringify({ name: "allourthings-claude-extension", version, private: true, type: "module" }, null, 2)}\n`
);

copy(join(serverRoot, "dist"), join(stageRoot, "server", "dist"));
copy(join(serverRoot, "package.json"), join(stageRoot, "server", "package.json"));
for (const file of requiredCoreFiles) {
  copy(join(coreRoot, file), join(stageRoot, "server", "node_modules", "@allourthings", "core", file));
}

mkdirSync(releaseRoot, { recursive: true });
const archive = join(releaseRoot, `allourthings-claude-extension-${version}-${target.name}.mcpb`);
rmSync(archive, { force: true });
validateStage();
run(process.execPath, [join(stageRoot, "server", "dist", "index.js"), "--version"]);
packArchive(archive);

console.log(`Built ${archive}`);
