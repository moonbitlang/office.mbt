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
if [ "${1:-}" = "--root-alias" ]; then
  [ "$#" -ge 3 ] || usage
  root_alias="$(canonical_directory "$2")"
  shift 2
fi
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
use Digest::SHA ();
use Fcntl qw(S_ISDIR S_ISLNK S_ISREG);
use File::Find ();

my ($root, $root_alias, $label, @entries) = @ARGV;
my $root_marker = q{${INVENTORY_ROOT}};
my %seen_roots;
my @normalization_roots = sort { length($b) <=> length($a) }
  grep { $_ ne q{} && !$seen_roots{$_}++ } ($root, $root_alias);

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
for my $entry (@entries) {
  my $start = "$root/$entry";
  File::Find::find(
    {
      no_chdir => 1,
      follow => 0,
      wanted => sub { push @paths, $File::Find::name },
    },
    $start,
  );
}

my %seen;
@paths = sort @paths;
print "office.fresh-agent.tree-manifest/1\t$label\n";
for my $path (@paths) {
  die "inventory entries overlap at $path\n" if $seen{$path}++;
  die "inventory path escaped its root: $path\n"
    unless index($path, "$root/") == 0;
  my $relative = substr($path, length($root) + 1);
  die "inventory path contains unsafe syntax\n"
    if $relative eq q{} || $relative =~ /[\t\r\n]/;
  my @stat = lstat($path);
  die "could not stat inventory path: $relative\n" unless @stat;
  my $mode = $stat[2];
  if (S_ISLNK($mode)) {
    my $target = readlink($path);
    die "could not read inventory symlink: $relative\n" unless defined $target;
    die "inventory symlink has an unsafe target: $relative\n"
      if $target eq q{} || $target =~ m{(?:^/|(?:^|/)\.\.(?:/|$)|[\t\r\n])};
    print "L\t-\t-\t$target\t$relative\n";
  } elsif (S_ISDIR($mode)) {
    printf "D\t%04o\t-\t-\t%s\n", $mode & 07777, $relative;
  } elsif (
    S_ISREG($mode) &&
    $label ne 'dependencies' &&
    $relative =~ m{\Alib/core/_build/[^/]+/release/bundle/bundle\.moon_db\z}
  ) {
    # Moon regenerates these target-local lookup databases. Their record order
    # and path-derived fingerprints vary across equivalent installations, so
    # inventory their presence and mode while prepare.sh removes the databases
    # for every target it consumes before candidate code can run.
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
          m{\Alib/core/_build/[^/]+/release/bundle/all_pkgs\.json\z}
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
