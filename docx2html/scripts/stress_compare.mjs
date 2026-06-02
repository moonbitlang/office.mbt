#!/usr/bin/env node

import { createHash } from "node:crypto";
import { createWriteStream } from "node:fs";
import { mkdir, readFile, rm, stat, writeFile } from "node:fs/promises";
import { basename, dirname, join, resolve } from "node:path";
import { pipeline } from "node:stream/promises";
import { Readable } from "node:stream";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const workDir = join(root, "_build", "stress");
const fixtureDir = join(workDir, "fixtures");
const outputDir = join(workDir, "outputs");
const reportPath = join(workDir, "report.md");
const moonBinary = join(
  root,
  "_build",
  "native",
  "debug",
  "build",
  "cmd",
  "docx2html",
  "docx2html.exe",
);
const mammothBin = join(root, ".repos", "mammoth", "bin", "mammoth");

const sourceManifests = [
  {
    name: "docxcorp-legal-en",
    url: "https://api.docxcorp.us/manifest?type=legal&lang=en&min_confidence=0.8",
  },
  {
    name: "docxcorp-reports-en",
    url: "https://api.docxcorp.us/manifest?type=reports&lang=en&min_confidence=0.8",
  },
  {
    name: "docxcorp-technical-en",
    url: "https://api.docxcorp.us/manifest?type=technical&lang=en&min_confidence=0.8",
  },
];

const options = parseArgs(process.argv.slice(2));

await main();

async function main() {
  await mkdir(fixtureDir, { recursive: true });
  await mkdir(outputDir, { recursive: true });
  await ensureOriginalMammoth();
  await buildMoonBitCli();
  const candidates = await collectCandidates();
  const fixtures = await downloadFixtures(candidates);
  const results = [];
  for (const fixture of fixtures) {
    console.error(
      `converting ${fixture.label} (${formatBytes(fixture.sizeBytes)})`,
    );
    results.push(await compareFixture(fixture));
  }
  await writeReport(results);
  console.error(`wrote ${relative(reportPath)}`);
}

function parseArgs(args) {
  const parsed = {
    count: 3,
    maxProbe: 80,
    minSize: 250_000,
    concurrency: 8,
    timeoutMs: 120_000,
  };
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    switch (arg) {
      case "--count":
        parsed.count = parsePositiveInt(args[++index], "--count");
        break;
      case "--max-probe":
        parsed.maxProbe = parsePositiveInt(args[++index], "--max-probe");
        break;
      case "--min-size":
        parsed.minSize = parsePositiveInt(args[++index], "--min-size");
        break;
      case "--concurrency":
        parsed.concurrency = parsePositiveInt(args[++index], "--concurrency");
        break;
      case "--timeout-ms":
        parsed.timeoutMs = parsePositiveInt(args[++index], "--timeout-ms");
        break;
      case "--help":
        printUsage();
        process.exit(0);
      default:
        throw new Error(`Unknown option: ${arg}`);
    }
  }
  return parsed;
}

function parsePositiveInt(value, flag) {
  const number = Number(value);
  if (!Number.isInteger(number) || number <= 0) {
    throw new Error(`${flag} expects a positive integer`);
  }
  return number;
}

function printUsage() {
  console.log(`Usage: node scripts/stress_compare.mjs [options]

Options:
  --count <n>        Number of DOCX fixtures to download and compare. [default: 3]
  --max-probe <n>    Number of URLs to size-probe from each manifest. [default: 80]
  --min-size <n>     Preferred minimum DOCX byte size. [default: 250000]
  --concurrency <n>  Concurrent HEAD/download probes. [default: 8]
  --timeout-ms <n>   Timeout per converter run. [default: 120000]
`);
}

async function ensureOriginalMammoth() {
  try {
    await stat(mammothBin);
  } catch {
    throw new Error(`Original Mammoth CLI not found at ${relative(mammothBin)}`);
  }
}

async function buildMoonBitCli() {
  console.error("building MoonBit CLI");
  const result = await runProcess("moon", ["build", "--target", "native", "cmd/docx2html"], {
    cwd: root,
    timeoutMs: options.timeoutMs,
  });
  if (result.exitCode !== 0) {
    throw new Error(`moon build failed:\n${result.stderr}`);
  }
}

async function collectCandidates() {
  console.error(
    `probing ${options.maxProbe} URLs from each corpus manifest with concurrency ${options.concurrency}`,
  );
  const urls = [];
  for (const source of sourceManifests) {
    const text = await fetchText(source.url);
    const sourceUrls = text
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.endsWith(".docx"))
      .slice(0, options.maxProbe);
    for (const url of sourceUrls) {
      urls.push({ source: source.name, url });
    }
  }
  const unique = dedupeBy(urls, (entry) => entry.url);
  const probed = await mapLimit(unique, options.concurrency, probeCandidate);
  const candidates = probed
    .filter((candidate) => candidate.sizeBytes > 0)
    .sort((left, right) => right.sizeBytes - left.sizeBytes);
  const preferred = candidates.filter(
    (candidate) => candidate.sizeBytes >= options.minSize,
  );
  const selected = (preferred.length >= options.count ? preferred : candidates).slice(
    0,
    options.count,
  );
  if (selected.length === 0) {
    throw new Error("No downloadable DOCX candidates were found");
  }
  return selected;
}

async function fetchText(url) {
  const response = await fetch(url, {
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) {
    throw new Error(`${url} returned HTTP ${response.status}`);
  }
  return await response.text();
}

async function probeCandidate(entry) {
  try {
    const response = await fetch(entry.url, {
      method: "HEAD",
      signal: AbortSignal.timeout(20_000),
    });
    if (!response.ok) {
      return { ...entry, sizeBytes: 0 };
    }
    const sizeBytes = Number(response.headers.get("content-length") ?? 0);
    return { ...entry, sizeBytes };
  } catch {
    return { ...entry, sizeBytes: 0 };
  }
}

async function downloadFixtures(candidates) {
  const fixtures = [];
  for (const candidate of candidates) {
    const id = basename(candidate.url, ".docx");
    const label = `${candidate.source}-${id.slice(0, 12)}`;
    const path = join(fixtureDir, `${label}.docx`);
    let currentSize = 0;
    try {
      currentSize = (await stat(path)).size;
    } catch {
      currentSize = 0;
    }
    if (currentSize !== candidate.sizeBytes) {
      console.error(`downloading ${label} (${formatBytes(candidate.sizeBytes)})`);
      const response = await fetch(candidate.url, {
        signal: AbortSignal.timeout(120_000),
      });
      if (!response.ok || response.body === null) {
        throw new Error(`${candidate.url} returned HTTP ${response.status}`);
      }
      await pipeline(Readable.fromWeb(response.body), createWriteStream(path));
    }
    fixtures.push({ ...candidate, id, label, path });
  }
  return fixtures;
}

async function compareFixture(fixture) {
  const moonOutput = join(outputDir, `${fixture.label}.moon.html`);
  const mammothOutput = join(outputDir, `${fixture.label}.mammoth.html`);
  await rm(moonOutput, { force: true });
  await rm(mammothOutput, { force: true });

  const moon = await runProcess(moonBinary, [fixture.path, moonOutput], {
    cwd: root,
    timeoutMs: options.timeoutMs,
  });
  const mammoth = await runProcess("node", [mammothBin, fixture.path, mammothOutput], {
    cwd: root,
    timeoutMs: options.timeoutMs,
  });

  const moonStats = await outputStats(moonOutput, moon.exitCode === 0);
  const mammothStats = await outputStats(mammothOutput, mammoth.exitCode === 0);
  return {
    fixture,
    moon,
    mammoth,
    moonStats,
    mammothStats,
    sameOutput:
      moonStats.sha256 !== "" && moonStats.sha256 === mammothStats.sha256,
    sameStderr: moon.stderr === mammoth.stderr,
  };
}

async function outputStats(path, shouldExist) {
  try {
    const content = await readFile(path);
    return {
      path,
      sizeBytes: content.length,
      sha256: createHash("sha256").update(content).digest("hex"),
    };
  } catch (error) {
    if (shouldExist) {
      throw error;
    }
    return { path, sizeBytes: 0, sha256: "" };
  }
}

function runProcess(command, args, config) {
  return new Promise((resolveResult) => {
    const started = process.hrtime.bigint();
    const child = spawn(command, args, {
      cwd: config.cwd,
      stdio: ["ignore", "pipe", "pipe"],
    });
    const stdoutChunks = [];
    const stderrChunks = [];
    const timer = setTimeout(() => {
      child.kill("SIGTERM");
    }, config.timeoutMs);
    child.stdout.on("data", (chunk) => stdoutChunks.push(chunk));
    child.stderr.on("data", (chunk) => stderrChunks.push(chunk));
    child.on("close", (exitCode, signal) => {
      clearTimeout(timer);
      const ended = process.hrtime.bigint();
      resolveResult({
        command,
        args,
        exitCode,
        signal,
        ms: Number(ended - started) / 1_000_000,
        stdout: Buffer.concat(stdoutChunks).toString("utf8"),
        stderr: Buffer.concat(stderrChunks).toString("utf8"),
      });
    });
  });
}

async function writeReport(results) {
  const lines = [];
  lines.push("# DOCX Stress Comparison");
  lines.push("");
  lines.push(`Generated: ${new Date().toISOString()}`);
  lines.push("");
  lines.push("Fixtures are downloaded into `_build/stress/fixtures` from:");
  for (const source of sourceManifests) {
    lines.push(`- ${source.name}: ${source.url}`);
  }
  lines.push("");
  lines.push(
    "| fixture | docx size | moon exit | moon ms | moon html | mammoth exit | mammoth ms | mammoth html | exact hash match | stderr match |",
  );
  lines.push("|---|---:|---:|---:|---:|---:|---:|---:|---|---|");
  for (const result of results) {
    const cells = [
      markdownLink(result.fixture.label, relative(result.fixture.path)),
      formatBytes(result.fixture.sizeBytes),
      String(exitStatus(result.moon)),
      formatMs(result.moon.ms),
      formatBytes(result.moonStats.sizeBytes),
      String(exitStatus(result.mammoth)),
      formatMs(result.mammoth.ms),
      formatBytes(result.mammothStats.sizeBytes),
      result.sameOutput ? "yes" : "no",
      result.sameStderr ? "yes" : "no",
    ];
    lines.push(`| ${cells.join(" | ")} |`);
  }
  lines.push("");
  lines.push("## Details");
  lines.push("");
  for (const result of results) {
    lines.push(`### ${result.fixture.label}`);
    lines.push("");
    lines.push(`Source: ${result.fixture.url}`);
    lines.push("");
    lines.push(`MoonBit output: \`${relative(result.moonStats.path)}\``);
    lines.push(`Mammoth output: \`${relative(result.mammothStats.path)}\``);
    lines.push("");
    lines.push(`MoonBit stderr: ${codeOrDash(trimForReport(result.moon.stderr))}`);
    lines.push(`Mammoth stderr: ${codeOrDash(trimForReport(result.mammoth.stderr))}`);
    lines.push("");
  }
  await writeFile(reportPath, `${lines.join("\n")}\n`, "utf8");
}

function dedupeBy(values, key) {
  const seen = new Set();
  const result = [];
  for (const value of values) {
    const id = key(value);
    if (!seen.has(id)) {
      seen.add(id);
      result.push(value);
    }
  }
  return result;
}

async function mapLimit(values, limit, mapper) {
  const result = new Array(values.length);
  let next = 0;
  async function worker() {
    while (next < values.length) {
      const index = next;
      next += 1;
      result[index] = await mapper(values[index], index);
    }
  }
  const workers = Array.from(
    { length: Math.min(limit, values.length) },
    () => worker(),
  );
  await Promise.all(workers);
  return result;
}

function exitStatus(result) {
  return result.signal === null ? result.exitCode : result.signal;
}

function formatMs(ms) {
  return String(Math.round(ms));
}

function formatBytes(bytes) {
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`;
  }
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function markdownLink(text, href) {
  return `[${escapePipe(text)}](${href})`;
}

function escapePipe(text) {
  return text.replaceAll("|", "\\|");
}

function codeOrDash(text) {
  return text === "" ? "-" : `\`${text.replaceAll("`", "'")}\``;
}

function trimForReport(text) {
  const trimmed = text.trim().replace(/\s+/g, " ");
  return trimmed.length > 240 ? `${trimmed.slice(0, 237)}...` : trimmed;
}

function relative(path) {
  return path.startsWith(root) ? path.slice(root.length + 1) : path;
}
