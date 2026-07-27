#!/bin/sh
set -eu

if [ "$#" -ne 13 ]; then
  echo "permission canary: expected 13 arguments" >&2
  exit 2
fi

candidate_root="$1"
original_install_root="$2"
probe_root="$3"
scratch_root="$4"
evidence_root="$5"
isolated_state="$6"
original_auth="$7"
source_root="$8"
git_common_dir="$9"
ambient_write_path="${10}"
network_port="${11}"
platform_name="${12}"
policy_readonly_root="${13}"

test -x "$candidate_root/bin/office-native"
test -x "$candidate_root/bin/office-wasm"

probe_marker="$probe_root/.permission-canary"
scratch_marker="$scratch_root/.permission-canary"
mkdir "$probe_marker"
mkdir "$scratch_marker"
rmdir "$probe_marker" "$scratch_marker"

if mkdir "$candidate_root/.permission-canary" >/dev/null 2>&1; then
  echo "permission canary: staged candidate is writable" >&2
  exit 11
fi
if ! ls "$policy_readonly_root" >/dev/null 2>&1; then
  echo "permission canary: policy read-only directory is not readable" >&2
  exit 26
fi
if mkdir "$policy_readonly_root/.permission-canary" >/dev/null 2>&1; then
  echo "permission canary: policy read-only directory is writable" >&2
  exit 27
fi
if cat "$candidate_root/CANDIDATE.json" >/dev/null 2>&1; then
  echo "permission canary: staged candidate manifest is readable" >&2
  exit 25
fi
if ls "$candidate_root/control" >/dev/null 2>&1; then
  echo "permission canary: staged controller directory is readable" >&2
  exit 12
fi
if ls "$original_install_root" >/dev/null 2>&1; then
  echo "permission canary: original candidate is readable" >&2
  exit 13
fi
if ls "$evidence_root" >/dev/null 2>&1; then
  echo "permission canary: evidence directory is readable" >&2
  exit 14
fi
if cat "$isolated_state/credential-canary" >/dev/null 2>&1; then
  echo "permission canary: isolated credential state is readable" >&2
  exit 15
fi
if [ -n "$original_auth" ] && cat "$original_auth" >/dev/null 2>&1; then
  echo "permission canary: original credential is readable" >&2
  exit 16
fi
if ls "$source_root" >/dev/null 2>&1; then
  echo "permission canary: candidate checkout is readable" >&2
  exit 17
fi
if ls "$git_common_dir" >/dev/null 2>&1; then
  echo "permission canary: Git common directory is readable" >&2
  exit 18
fi
if [ "$platform_name" != "Darwin" ]; then
  if cat /etc/hosts >/dev/null 2>&1; then
    echo "permission canary: ambient /etc data is readable" >&2
    exit 19
  fi
  if cat /etc/passwd >/dev/null 2>&1; then
    echo "permission canary: ambient account data is readable" >&2
    exit 20
  fi
  if ls /tmp >/dev/null 2>&1; then
    echo "permission canary: ambient temporary storage is readable" >&2
    exit 21
  fi
fi
if mkdir "$ambient_write_path" >/dev/null 2>&1; then
  echo "permission canary: ambient temporary storage is writable" >&2
  exit 22
fi
if [ -n "${CODEX_HOME:-}" ]; then
  echo "permission canary: CODEX_HOME leaked into child commands" >&2
  exit 23
fi
if /bin/bash -p -c 'exec 3<>/dev/tcp/127.0.0.1/$1' \
  office-permission-canary "$network_port" >/dev/null 2>&1; then
  echo "permission canary: loopback network is reachable" >&2
  exit 24
fi

"$candidate_root/bin/office-native" help all --json \
  > "$scratch_root/native-help.json"
"$candidate_root/bin/office-wasm" help all --json \
  > "$scratch_root/wasm-help.json"
cmp "$scratch_root/native-help.json" "$scratch_root/wasm-help.json"
rm -f "$scratch_root/native-help.json" "$scratch_root/wasm-help.json"

# Exercise the same privately staged attester that every full-probe workflow
# uses. This keeps the unauthenticated real-sandbox canary from passing when the
# controller is readable only to the host but unavailable to command children.
for runtime in native wasm; do
  runtime_root="$scratch_root/$runtime-attest"
  mkdir "$runtime_root"
  (
    cd "$runtime_root"
    "office-$runtime" create xlsx canary.xlsx --json \
      --attest-result canary-result.json > canary-attestation.txt
    test -s canary.xlsx
    test -s canary-result.json
    test "$(wc -l < canary-attestation.txt | tr -d ' ')" = 1
    grep -q '^OFFICE_F1B_ATTESTATION' canary-attestation.txt
    jq -e '
      .schema == "office.output/1" and
      .success == true and
      .data.schema == "office.xlsx.create/1" and
      .data.format == "xlsx" and
      .data.transaction.committed == true
    ' canary-result.json >/dev/null
    rm -f canary.xlsx canary-result.json canary-attestation.txt
  )
  rmdir "$runtime_root"
done

echo "FRESH-AGENT PERMISSION CANARY PASS"
