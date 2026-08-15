#!/bin/bash -p

case "$-" in
  *p*) ;;
  *)
    echo "error: execute inventory.sh directly so Bash privileged mode can ignore BASH_ENV" >&2
    exit 2
    ;;
esac

set -euo pipefail
umask 077

PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
unset BASH_ENV ENV CDPATH PERL5OPT PERL5LIB TAR_OPTIONS POSIXLY_CORRECT BLOCKSIZE
unset DYLD_INSERT_LIBRARIES DYLD_LIBRARY_PATH LD_PRELOAD LD_LIBRARY_PATH

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  echo "usage: $0 ROOT ABSENT_OUTPUT LABEL [--root-alias ROOT] RELATIVE_ENTRY..." >&2
  exit 2
}

canonical_directory() {
  (
    unset CDPATH
    cd -P -- "$1" >/dev/null
    pwd -P
  )
}

[ "$#" -ge 4 ] || usage
root="$(canonical_directory "$1")"
output="$2"
label="$3"
shift 3
root_alias=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root-alias)
      [ "$#" -ge 3 ] || usage
      [ -z "$root_alias" ] || die "--root-alias may be supplied only once"
      root_alias="$(canonical_directory "$2")"
      shift 2
      ;;
    *) break ;;
  esac
done
[ "$#" -ge 1 ] || usage

case "$output" in
  /*) ;;
  *) die "manifest output must be absolute: $output" ;;
esac
[ ! -e "$output" ] && [ ! -L "$output" ] ||
  die "manifest output must not already exist: $output"
case "$label" in
  "" | *$'\t'* | *$'\n'* | *$'\r'*) die "manifest label contains unsafe syntax" ;;
esac

manifest_tmp="$(/usr/bin/mktemp "$output.tmp.XXXXXX")"
cleanup() {
  local status="$1"
  trap - EXIT HUP INT TERM
  /bin/rm -f -- "$manifest_tmp" 2>/dev/null || true
  exit "$status"
}
trap 'cleanup $?' EXIT
trap 'cleanup 129' HUP
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

for entry in "$@"; do
  case "$entry" in
    "" | /* | . | .. | ./* | */./* | */. | *//* | ../* | */../* | */.. | \
    *$'\t'* | *$'\n'* | *$'\r'*)
      die "inventory entry is not a safe relative path: $entry"
      ;;
  esac
  [ -e "$root/$entry" ] || [ -L "$root/$entry" ] ||
    die "inventory entry does not exist: $entry"
done

if ! /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/perl - "$root" "$root_alias" "$label" "$@" \
    > "$manifest_tmp" <<'PERL'
use strict;
use warnings;
use bytes;
use Cwd ();
use Digest::SHA ();
use Fcntl qw(S_ISDIR S_ISLNK S_ISREG);
use File::Find ();

my ($root, $root_alias, $label, @entries) = @ARGV;
my $root_marker = q{${INVENTORY_ROOT}};
my %seen_roots;
my @normalization_roots = sort { length($b) <=> length($a) }
  grep { $_ ne q{} && $_ ne q{/} && !$seen_roots{$_}++ }
  ($root, $root_alias);

sub path_within_root {
  my ($path) = @_;
  return index($path, q{/}) == 0 if $root eq q{/};
  return $path eq $root || index($path, "$root/") == 0;
}

sub relative_to_root {
  my ($path) = @_;
  return substr($path, 1) if $root eq q{/};
  return substr($path, length($root) + 1);
}

sub root_entry_path {
  my ($entry) = @_;
  return "/$entry" if $root eq q{/};
  return "$root/$entry";
}

sub normalized_file_fingerprint {
  my ($file, $relative) = @_;
  my $content = q{};
  while (1) {
    my $read = read($file, my $chunk, 1024 * 1024);
    die "could not read inventory file: $relative\n" unless defined $read;
    last if $read == 0;
    $content .= $chunk;
  }
  for my $inventory_root (@normalization_roots) {
    $content =~ s/\Q$inventory_root\E/$root_marker/g;
  }
  return (length($content), Digest::SHA::sha256_hex($content));
}

my @paths;
my @pending_starts = map { root_entry_path($_) } @entries;
my %collected;
my %scanned_starts;
while (@pending_starts) {
  my $start = shift @pending_starts;
  next if $scanned_starts{$start}++ || $collected{$start};
  die "inventory closure escaped its root: $start\n"
    unless path_within_root($start) && $start ne $root;
  File::Find::find(
    {
      no_chdir => 1,
      follow => 0,
      wanted => sub {
        my $path = $File::Find::name;
        return if $collected{$path}++;
        push @paths, $path;
        die "inventory closure exceeds 200000 entries\n"
          if @paths > 200000;
        my @stat = lstat($path);
        die "could not stat inventory path during closure: $path\n"
          unless @stat;
        return unless S_ISLNK($stat[2]);
        my $resolved = Cwd::realpath($path);
        die "inventory contains a broken symlink: $path\n"
          unless defined $resolved;
        die "inventory symlink referent escaped its root: $path\n"
          unless path_within_root($resolved) && $resolved ne $root;
        for my $covered_start (keys %scanned_starts) {
          return if $resolved eq $covered_start ||
            index($resolved, "$covered_start/") == 0;
        }
        push @pending_starts, $resolved
          unless $collected{$resolved} || $scanned_starts{$resolved};
      },
    },
    $start,
  );
}

@paths = sort @paths;
print "office.fresh-agent.tree-manifest/1\t$label\n";
for my $path (@paths) {
  die "inventory path escaped its root: $path\n"
    unless path_within_root($path);
  my $relative = relative_to_root($path);
  die "inventory path contains unsafe syntax\n"
    if $relative eq q{} || $relative =~ /[\t\r\n]/;
  my @stat = lstat($path);
  die "could not stat inventory path: $relative\n" unless @stat;
  my $mode = $stat[2];
  if (S_ISLNK($mode)) {
    my $target = readlink($path);
    die "could not read inventory symlink: $relative\n" unless defined $target;
    die "inventory symlink has an unsafe target: $relative\n"
      if $target eq q{} || $target =~ m{[\t\r\n]};
    print "L\t-\t-\t$target\t$relative\n";
  } elsif (S_ISDIR($mode)) {
    printf "D\t%04o\t-\t-\t%s\n", $mode & 07777, $relative;
  } elsif (
    S_ISREG($mode) &&
    $label ne 'dependencies' &&
    (
      $relative =~ m{\Alib/core/_build/[^/]+/release/bundle/bundle\.moon_db\z} ||
      $relative eq 'lib/core/_build/.moon_db'
    )
  ) {
    # Moon regenerates these lookup databases. Their record order and
    # path-derived fingerprints vary across equivalent installations, so
    # inventory their presence and mode while prepare.sh removes them before
    # candidate code can run. Where they live is a toolchain detail that has
    # already moved once: 0.10.7 writes one per target under
    # <target>/release/bundle, 0.10.8 writes a single _build/.moon_db.
    printf "G\t%04o\t-\t-\t%s\n", $mode & 07777, $relative;
  } elsif (S_ISREG($mode)) {
    open my $file, '<:raw', $path
      or die "could not open inventory file: $relative\n";
    my ($inventory_size, $sha256);
    if (
      $label ne 'dependencies' &&
      (
        $relative eq 'lib/core/_build/packages.json' ||
        $relative =~
          m{\Alib/core/_build/[^/]+/release/bundle/(?:all_pkgs|packages)\.json\z}
      )
    ) {
      ($inventory_size, $sha256) =
        normalized_file_fingerprint($file, $relative);
    } else {
      $inventory_size = $stat[7];
      $sha256 = Digest::SHA->new(256)->addfile($file)->hexdigest;
    }
    close $file or die "could not close inventory file: $relative\n";
    printf "F\t%04o\t%d\t%s\t%s\n",
      $mode & 07777, $inventory_size, $sha256, $relative;
  } else {
    die "inventory contains an unsupported filesystem entry: $relative\n";
  }
}
PERL
then
  die "could not generate the $label inventory"
fi

/bin/mv "$manifest_tmp" "$output"
manifest_tmp=""
trap - EXIT HUP INT TERM
