# Installed-command fresh-agent probe

This is the uncoached half of the F1b baseline. It builds one exact commit from
a fresh exported snapshot, publishes native and Wasm commands outside the
checkout, and gives a new Codex session only those commands and their installed
help. The task prompt contains outcomes, not product command syntax, JSON
examples, repository paths, or corrective hints.

The scripts are security gates. Execute them directly so their fixed
`#!/bin/bash -p` interpreter can reject `BASH_ENV` startup hooks. Invoking them
as `bash script.sh` is deliberately rejected.

## Prepare an exact candidate

Start from a clean checkout. Pass the full 40-character HEAD, an absent install
path under a private existing parent, and the exact Moon compiler/runtime files
plus caller-computed SHA-256 values. Linux must keep every harness-owned path
outside `/tmp`, which the permission profile deliberately denies; use a private
directory beneath `/var/tmp`. macOS must use its private per-user `TMPDIR`:

```sh
head="$(git rev-parse --verify HEAD)"
case "$(uname -s)" in
  Linux) scratch_root=/var/tmp ;;
  Darwin) scratch_root="${TMPDIR:?TMPDIR must be set on macOS}" ;;
  *) scratch_root="${TMPDIR:-/tmp}" ;;
esac
install_parent="$(mktemp -d "$scratch_root/office-f1b-install.XXXXXX")"
prefix="$install_parent/candidate"
moon_bin="$(command -v moon)"
moonc_bin="$(command -v moonc)"
moonrun_bin="$(command -v moonrun)"
moon_sha="$(/usr/bin/shasum -a 256 "$moon_bin" |
  /usr/bin/awk '{print substr($1, length($1) - 63)}')"
moonc_sha="$(/usr/bin/shasum -a 256 "$moonc_bin" |
  /usr/bin/awk '{print substr($1, length($1) - 63)}')"
moonrun_sha="$(/usr/bin/shasum -a 256 "$moonrun_bin" |
  /usr/bin/awk '{print substr($1, length($1) - 63)}')"
office/tests/acceptance/fresh-agent/prepare.sh \
  "$head" "$prefix" \
  "$moon_bin" "$moon_sha" \
  "$moonc_bin" "$moonc_sha" \
  "$moonrun_bin" "$moonrun_sha"
```

The installer sanitizes its startup environment, derives the checkout from its
own physical path, disables Git replacement objects plus ambient configuration
and attributes, and exports the exact tree bound to `head`. It verifies the
supplied `moon`,
`moonc`, and `moonrun` hashes, resolves that closure under `env -i`, then
performs frozen native and Wasm release builds in the snapshot. Every tracked
controller asset is copied from the snapshot, never from the mutable checkout.

The absent destination is atomically reserved before the build. Fixed
subtrees are published without clobbering, directory modes are locked, and
`CANDIDATE.json` is linked into place last as the atomic commit marker. A prefix
without that marker is incomplete. The manifest records the full commit and
source-tree identity, driver/code-generator/runtime and dependency-tree hashes,
capability identity, and hashes and modes for every candidate file. The runner
additionally requires one hard link per regular file and exact directory modes.

Record the manifest digest outside the candidate; it is the trust anchor for
the run:

```sh
candidate_sha="$(/usr/bin/shasum -a 256 "$prefix/CANDIDATE.json" |
  /usr/bin/awk '{print substr($1, length($1) - 63)}')"
```

## Select an approved Codex runtime closure

The runner requires Codex CLI 0.145.0 or newer and an explicit executable
SHA-256. Use the platform-native Codex executable, not the mutable npm JavaScript
launcher. For the official npm package, the native executable is under the
installed platform package's `vendor/.../bin/codex` directory:

```sh
codex_native="$(find "$(npm root -g)/@openai" -type f \
  -path '*/vendor/*/bin/codex' -print | head -n 1)"
codex_sha="$(/usr/bin/shasum -a 256 "$codex_native" |
  /usr/bin/awk '{print substr($1, length($1) - 63)}')"
"$codex_native" --version
```

On Linux, also select and hash the exact `bwrap` that Codex will execute. Codex
prefers the first system `bwrap` on its sanitized `PATH`; the runner therefore
requires that executable to be the caller-approved one:

```sh
codex_bwrap="$(command -v bwrap || true)"
if [ -z "$codex_bwrap" ]; then
  codex_vendor="$(/usr/bin/dirname "$(/usr/bin/dirname "$codex_native")")"
  codex_bwrap="$codex_vendor/codex-resources/bwrap"
fi
test -f "$codex_bwrap" && test -x "$codex_bwrap"
bwrap_sha="$(/usr/bin/shasum -a 256 "$codex_bwrap" |
  /usr/bin/awk '{print substr($1, length($1) - 63)}')"
```

If no system `bwrap` exists, select the resource shipped beside the approved
native Codex instead; the runner will copy it into the same relative layout as
the privately staged Codex. The branch above selects that resource before
computing `bwrap_sha`, so the supplied digest always binds the selected file.

The runner privately stages and repeatedly verifies Codex. A selected system
`bwrap` is accepted in place only when it is root-owned, executable, not
group/other-writable, free of special mode bits, on the sanitized `PATH`, and
still matches the caller's digest at every integrity checkpoint. With no system
helper, the approved fallback is privately staged and checked instead. Every
version/canary/session operation runs under `env -i`. Exact `#!/bin/sh` and
`#!/bin/bash` test executables are also supported with fixed system
interpreters; other shebangs are rejected and cannot accept a `bwrap`.

## Run in least privilege

Use the runner copied into the candidate. Probe and evidence paths must be
absent siblings under a fresh private parent outside protected home/workspace
storage. On Linux, the install, probe, evidence, source checkout, Git common
directory, and auth file must also remain outside `/tmp`; this keeps all scoped
read/write roots disjoint from the ambient `/tmp` denial used by bubblewrap.
The real auth file must be private, regular, single-linked, and owned by the
caller:

```sh
case "$(uname -s)" in
  Linux) scratch_root=/var/tmp ;;
  Darwin) scratch_root="${TMPDIR:?TMPDIR must be set on macOS}" ;;
  *) scratch_root="${TMPDIR:-/tmp}" ;;
esac
run_parent="$(mktemp -d "$scratch_root/office-f1b-run.XXXXXX")"
probe="$run_parent/probe"
evidence="$run_parent/evidence"
auth_json="$HOME/.codex/auth.json"
"$prefix/control/run.sh" \
  "$head" "$candidate_sha" \
  "$probe" "$evidence" \
  "$auth_json" "$codex_native" "$codex_sha"
```

Native Linux runs append `"$codex_bwrap" "$bwrap_sha"` as the final two
arguments. macOS runs and explicit test scripts omit them.

The runner revalidates the externally anchored candidate, privately stages the
entire candidate and approved Codex, and verifies the selected Linux sandbox
helper as described above. The credential is copied only after every
unauthenticated preflight and debug-sandbox canary has passed; the cleanup trap
is armed before any copy.

Codex receives a generated isolated configuration:

- the custom profile starts from Codex's `:minimal`, never `:root`, and adds
  only the candidate runtime closure and the two output roots;
- ambient `/tmp`, source/Git storage, the original candidate,
  controllers, auth/state, and evidence are denied;
- the staged candidate is mounted read-only while its manifest and controller
  subtree remain denied; the exact staged Codex executable needed by Linux
  bubblewrap re-entry, the isolated shell home, and the fixed canary launcher
  are the other readable roots, and any privately staged `bwrap` resource
  itself remains denied;
- only the empty probe directory and isolated Office-child scratch directory
  are writable inside the sandbox; a dedicated mode-0700 policy sentinel is
  host-writable before and after the canary but explicitly read-only in the
  profile. Codex's controller `TMPDIR` stays inside its denied private state,
  and fixed read-only command launchers select the child `TMPDIR` only after
  sandbox entry so Linux bubblewrap bookkeeping cannot enter it;
- network, web search, MCP servers, hooks, login shells, project instructions,
  skills, plugins, apps, browser/Computer Use, memories, and subagents are
  disabled; and
- the live invocation explicitly selects `fresh_agent`; the debug sandbox
  selects the same profile with `--include-managed-config`.

The debug canary and the first command of the real model session both test
candidate read/no-write, controller/original/source/auth/state/evidence denial,
absence of child `CODEX_HOME`, native/Wasm execution, and denial of a
connection to a live host loopback listener. Linux additionally proves ambient
`/etc` and temporary-storage read denial. The policy sentinel distinguishes a
sandbox write denial from ordinary DAC mode denial. A mismatch aborts the
probe.

Codex 0.145.0's built-in macOS `:minimal` policy itself permits standard
system configuration plus `/private/tmp`; custom deny entries cannot override
those later platform-default Seatbelt rules. The runner therefore refuses to
place the candidate, auth, probe, evidence, or isolation under any such macOS
platform-default root. Run macOS probes only on a disposable host whose ambient
temporary storage contains no unrelated secrets. The Linux canary is the
strict ambient-read gate; the macOS canary gates product behavior and every
harness-owned secret/output boundary.

CI can run the unauthenticated half against a prepared candidate and pinned
real Codex executable:

```sh
"$prefix/control/run.sh" --canary-only \
  "$head" "$candidate_sha" \
  "$run_parent/probe" "$run_parent/evidence" \
  "$codex_native" "$codex_sha"
```

As with a full run, append the approved `bwrap` path and digest on native
Linux.

Bubblewrap also requires host support for unprivileged user namespaces.
GitHub-hosted Ubuntu 24.04 enables an AppArmor gate that otherwise rejects the
namespace setup. The CI workflow follows the
[official `codex-action` prerequisite](https://github.com/openai/codex-action/blob/dd78cb653811af44014baa08fe954e28d32c1bf9/action.yml#L278-L301)
immediately before its canary: it enables
`kernel.unprivileged_userns_clone` when present, temporarily clears
`kernel.apparmor_restrict_unprivileged_userns`, and restores both original
values through an EXIT trap on success or failure. The runner itself never
changes host policy; self-hosted machines must provide a supported namespace
configuration administratively.

## Evidence and cleanup

Successful full completion requires a zero Codex status, valid JSONL on stdout
with stderr retained separately, the exact live canary as the first command,
host-bound events for all 58 required runtime/format/operation workflows, a
strict per-target final object, and the exact nine-line machine-readable summary
in `probe-result.md`. Format-bearing evidence must name its target before any
output redirection and cannot contain status-masking control operators.
`BASELINE PASS` requires all four runtime/format outcomes to pass and no P0-P2
gap. `BASELINE FAIL` returns 3.

The evidence directory contains:

- the anchored `CANDIDATE.json`, generated `CONFIG.toml`,
  `RUN-PREFLIGHT.json`, and `RUN.json`;
- `permission-canary.log`, host-derived `COMMANDS.json` and `WORKFLOWS.json`,
  `codex-transcript.jsonl`, separate `codex-stderr.log`, final message, and exit
  status;
- the agent-authored semantic result `probe-result.md` and the host-generated
  `probe-transcript.md`, which renders every paired command event in start
  order; and
- `EVIDENCE.json`, which records the byte length and SHA-256 of every retained
  artifact other than itself.

The run manifests record the selected bubblewrap strategy (`system` or
`private`), exact digest, and whether it was privately staged.

Publish the complete non-secret evidence directory (for example as a CI
artifact or an unlisted durable review attachment), not hashes without their
recomputable inputs.

The normal EXIT/HUP/INT/TERM trap deletes the isolated Codex home and credential
copy. SIGKILL and machine failure cannot run a trap; use a one-shot private
parent and remove it after evidence collection. If the candidate head changes,
discard the prefix and evidence and repeat from preparation. Record every P0-P2
product gap under the Office parity epic; this baseline does not close the epic.
