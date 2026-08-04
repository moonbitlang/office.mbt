# Installed-command fresh-agent probe

This is the constrained, protocol-driven installed-command half of the F1b
baseline. It builds one exact commit from a fresh exported snapshot, publishes
native and Wasm commands outside the checkout, and gives a new Codex session
only those commands and their installed help. Installed help remains the only
product documentation and the prompt contains no JSON contract examples or
repository paths. The prompt deliberately prescribes the coverage matrix and a
canonical evidence-command grammar, so this gate measures installed-command
task completion under that protocol; it is not an uncoached discoverability
experiment.

The scripts are security gates. Execute them directly so their fixed
`#!/bin/bash -p` interpreter can reject `BASH_ENV` startup hooks. Invoking them
as `bash script.sh` is deliberately rejected.

## Prepare an exact candidate

Start from a clean checkout. Pass the full 40-character HEAD, an absent install
path under a private existing parent, and the canonical Moon compiler/runtime
files from one toolchain root. Linux must keep every harness-owned path
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
office/tests/acceptance/fresh-agent/prepare.sh \
  "$head" "$prefix" \
  "$moon_bin" "$moonc_bin" "$moonrun_bin"
```

The installer sanitizes its startup environment, derives the checkout from its
own physical path, disables Git replacement objects plus ambient configuration
and attributes, and exports the exact tree bound to `head`. It verifies a
relocatable inventory of the complete toolchain distribution against the
reviewed, platform-specific `build-lock.json` before executing it, privately
stages that exact closure, and resolves dependencies without compiling
candidate code. Moon's generated `all_pkgs.json` and `packages.json` indexes
embed the physical toolchain root, so only those known index contents are
hashed after replacing the current root and the preparer's explicit original
root alias with a fixed marker. Generated
`bundle.moon_db` lookup databases also have nondeterministic record order and
path-derived fingerprints, so their paths, types, and modes are inventoried but
their bytes are not. Every pinned js/LLVM/native/wasm-gc/wasm database is deleted
from the private stage before any target is consumed. The preparer repeats the
official all-target, LLVM, and wasm-gc bundle sequence from pinned core inputs,
restores the locked database modes, and reverifies the regenerated closure before
candidate dependency resolution or compilation. All other files, including the
compiler and runtime, are locked by their original bytes. The preparer inventories
the complete resolved dependency tree against the same lock before performing
only frozen native and Wasm release builds. Both inventories are reverified
after the build and retained with the candidate. Every tracked controller asset
is copied from the snapshot, never from the mutable checkout.

CI installs the immutable MoonBit snapshot named by the locked `moonc` version
(`0.10.5+001eef869-nightly`), rather than the mutable `nightly` CDN alias. Any deliberate
toolchain upgrade must update that workflow version and both platform inventories
in `build-lock.json` together. CI downloads the exact platform distribution and
core archives and verifies both tracked SHA-256 digests before either archive is
extracted or any downloaded executable is run. It then recreates the official
all-target, LLVM, and wasm-gc bundle sequence directly in an explicitly absent
private root under the per-job temporary directory, so a mutable installer,
preinstalled toolchain, or stale user state cannot enter the reviewed closure.
The Linux inventory is generated as a non-root user with `umask 0022`, matching
the hosted runner's installed `0644`/`0755` modes rather than root tar
extraction's group-writable modes.

The absent destination is atomically reserved before the build. Fixed
subtrees are published without clobbering, directory modes are locked, and
`CANDIDATE.json` is linked into place last as the atomic commit marker. A prefix
without that marker is incomplete. The manifest records the full commit and
source-tree identity, driver/code-generator/runtime hashes, build-lock identity,
complete toolchain and dependency inventories, and hashes and modes for every
candidate file. Native builds explicitly select `MOON_CC`, `MOON_AR`, and the
macOS `SDKROOT` from a fixed clean environment. Selected logical paths and
canonical referents are recorded separately, so compiler, archiver, SDK,
runtime, or plugin symlink changes remain visible. The normalized dry-run plan
is retained alongside deterministic discovery of compiler queries,
linker/assembler selection, search/resource paths, startup objects, link
scripts, compiler runtimes and plugins, and the dynamic-loader closure. Linux
records resolved `ldd` inputs; macOS records recursive Mach-O dependencies plus
the UUID and logical path of every image loaded by the tool probes, including
shared-cache images without standalone files. Existing files feed the
root-relative `build-host.manifest`, including selected symlinks and their
referents. The discovery, inventory bytes, Xcode selector results, OS identity,
and SDK version are recomputed after both release builds and must match
byte-for-byte. Runtime capability
identity is derived only from commands
executed inside the isolated probe; candidate code is never executed by the
preparer. The runner additionally requires one hard link per regular file and
exact directory modes.
Preparation scratch and staging directories are private siblings of the absent
destination, so the build does not depend on ambient `TMPDIR` or an executable
system `/tmp` mount.

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

Every Codex operation also runs in a dedicated process group. The controller
uses hard deadlines of 30 seconds for version discovery, 180 seconds for the
permission canary, and 1,800 seconds for the installed-command probe. The
corresponding `OFFICE_F1B_CODEX_*_TIMEOUT_SECONDS` variables may only lower
those bounds (the contract suite uses that path); they cannot extend them. A
deadline returns status 124 after TERM/KILL escalation. A leader exit does not
release supervision: the controller terminates and drains any remaining live
process-group member before it clears the PGID or continues, and removes the
staged credential before signaling descendants.

The controller also disables core dumps and caps every Codex process at a
128 MiB single-file size and 256 open descriptors. While the live probe runs,
it samples the probe plus both isolated scratch roots and aborts with status
125 if their combined allocation exceeds 512 MiB or 8,192 filesystem entries.
`OFFICE_F1B_PROBE_MAX_KIB` and `OFFICE_F1B_PROBE_MAX_ENTRIES` may lower those
limits within the runner's validated ranges. Failure to inspect either bound
is itself a policy violation. Successful model execution is followed by a
five-minute global post-processing budget. The validated
`OFFICE_F1B_POSTPROCESS_TIMEOUT_SECONDS` override may select one second through
the fixed ten-minute ceiling.

A POSIX process group is treated as bounded cleanup for normal descendants,
not as an unescapable cross-platform job object: a deliberately detaching child
could create another session. The pinned, hashed Codex runtime is therefore
part of the trusted controller boundary. Model-issued commands are separately
fail-closed: every recorded command must begin with an approved Office or
assertion executable and must not contain backgrounding, detachment,
scheduler/service-manager, interpreter, process-substitution, or `find -exec`
syntax. A run containing such an event cannot produce accepted evidence. The
permission canary independently proves model-issued commands cannot read the
privately staged credential.

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

The network-denial canary requires `nc` with the OpenBSD/BSD listener form
`nc -l -k HOST PORT`, Info-ZIP `unzip`, and the system Perl interpreter used by
the independent OPC metadata check. Ubuntu hosts should install
`netcat-openbsd`; macOS supplies the compatible BSD utility. Before staging the
real Codex credential, the runner feature-tests the listener by opening a
random loopback port and connecting to it. An unsupported dialect, failed bind,
or failed connection aborts the run.

## Evidence and cleanup

Successful full completion requires a zero Codex status, valid JSONL on stdout
with stderr retained separately, the exact live canary as the first command,
host-bound events for all 58 required runtime/format/operation workflows, a
strict per-target final object, and the exact nine-line machine-readable summary
in `probe-result.md`. Each non-help workflow must end in one unique JSON result
written through the wrapper-only `--attest-result` protocol. The wrapper invokes
the installed command only after a shared argument policy has classified every
filesystem-bearing token. It opens each consumed input component-by-component
without following symlinks, copies the held descriptor into a private read-only
`input-evidence/event-*/` snapshot, and records its argument index, role, access
mode, byte count, and SHA-256 in command-attestation schema v2. Read-only inputs
must retain the same identity and bytes until the command exits; in-place
operations retain the exact before-image. The wrapper then atomically publishes
the command JSON and emits canonical completion-time byte counts and SHA-256
digests for the result and every named Office/preview file in that same Codex
command event. The host revalidates every retained input snapshot, and final
bytes must still match all event-time digests before the operation-specific
schema/format/postconditions and referenced Office ZIP or preview artifact
validate. Office packages are subject to fixed compressed/expanded-size,
address-space, CPU, XML-part, and entry-count limits. Only stored and deflated
ZIP entries are accepted; raw-NUL/truncated names, special files, ambiguous or
case/URI-colliding part paths, and incomplete content-type coverage are
rejected. The validator parses every XML-typed part without DTDs/entities,
checks every relationships part and internal target, and requires the exact
root office-document relationship, main content type, part, and namespace. Probe
paths must be lowercase and may not traverse a symlinked parent, so
command-event IDs and result paths remain globally and physically unique on
both case-sensitive and case-insensitive filesystems. A quote-aware parser
normalizes the actual first token and permits only one simple command; input
redirection, comments, cross-format package decoys, help/version modes, shell
substitution or globbing, detachment syntax, unapproved executables, and every
control operator are rejected.
Before any whole-document query, a streaming parser limits the transcript to
32 MiB, 4,096 newline-terminated events, and 1 MiB per event; it also requires
one thread, one turn, a successful terminal turn, paired command lifecycle
events in causal order, integral shell exit codes, and agreement with the
outer Codex status. Final-message and stderr inputs are independently capped at
1 MiB and 8 MiB. These checks prevent malformed or oversized model output from
reaching `jq` aggregation or evidence generation.
`BASELINE PASS` requires all four runtime/format outcomes to pass and no P0-P2
gap. `BASELINE FAIL` returns 3.

The evidence directory contains:

- the anchored `CANDIDATE.json`, generated `CONFIG.toml`,
  `RUN-PREFLIGHT.json`, and `RUN.json`;
- `permission-canary.log`, host-derived `COMMANDS.json` and `WORKFLOWS.json`,
  `codex-transcript.jsonl`, separate `codex-stderr.log`, final message, and exit
  status; `WORKFLOWS.json` schema v4 binds every accepted event to its retained
  inputs, result, primary artifact, optional produced-output paths, and their
  event-time byte lengths and SHA-256 digests;
- the agent-authored semantic result `probe-result.md` and the host-generated
  `probe-transcript.md`, which renders every paired command event in start
  order; and
- one atomically published `closure/` containing the complete verified
  candidate (including every build/toolchain/dependency/host provenance
  record), an immutable snapshot of the complete probe tree, and the exact
  approved Codex executable plus bubblewrap when Linux selected it;
  `closure/runtime/RUNTIME.json` binds those runtime files to their versions,
  hashes, selection policy, candidate head, and candidate manifest; and
- `EVIDENCE.json` schema v2, which recursively records every retained file,
  directory, mode, symlink target, byte length, and SHA-256 other than itself.
  The installed `closure/candidate/control/evidence-policy.py verify` command
  recomputes that manifest without repository access.

Evidence publication shares the global post-processing deadline and is bounded
to 10,000 entries, 768 MiB cumulatively, and 512 MiB per file. Probe paths must
remain lowercase portable names; probe symlinks, hard links, special files,
group/world permissions, and changing inputs are rejected. The only retained
symlink is the reviewed relative `closure/candidate/bin/office` alias.

The run manifests record the selected bubblewrap strategy (`system` or
`private`), exact digest, and whether it was privately staged.

Publish the complete non-secret evidence directory (for example as a CI
artifact or an unlisted durable review attachment), not hashes without their
recomputable inputs. The original probe directory may also be retained for
operator convenience, but its immutable bytes are already inside
`closure/probe` so the evidence artifact is independently complete.

The normal EXIT/HUP/INT/TERM trap first blocks additional cleanup signals,
removes the staged credential, terminates the supervised process group and
resource monitor, and then deletes the isolated Codex home. The same cleanup
runs after a normal leader exit, including when a descendant ignores TERM.
SIGKILL and machine failure cannot run a trap; use a one-shot private parent
and remove it after evidence collection. If the candidate head changes,
discard the prefix and evidence and repeat from preparation. Record every
P0-P2 product gap under the Office parity epic; this baseline does not close
the epic.
