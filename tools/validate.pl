#!/usr/bin/perl
# Static validator for EU5 (Caesar/Jomini) mod files.
#
# Checks (no game launch needed):
#   * UTF-8 BOM on .txt / .yml files (vanilla script and localization files carry one)
#   * brace balance { } per file (comments and quoted strings ignored)
#   * localization: header l_<lang>: matches the file name, quote balance, duplicate keys
#   * script vocabulary: every "key =" used in mod script files must exist either in vanilla
#     (tools/cache/vanilla_script_keys.txt) or be defined by the mod itself (top-level keys,
#     scripted effects/triggers/values, static modifiers, unit types, on_actions ...)
#   * .gui: texture paths must exist in the mod or in the game
#
# Usage:  perl tools/validate.pl [--root <mod dir>] [--cache <vanilla key cache>] [--game <game dir>] [--strict]
#         exit code 1 on errors (brace mismatch, bad loc header), 2 if --strict and warnings exist
use strict;
use warnings;
use File::Find;
use File::Basename;

my $root  = '.';
my $game  = 'C:/Program Files (x86)/Steam/steamapps/common/Europa Universalis V';
my $cache_arg = '';
my $strict = 0;
while (@ARGV) {
    my $a = shift @ARGV;
    if    ($a eq '--root')   { $root = shift @ARGV; }
    elsif ($a eq '--game')   { $game = shift @ARGV; }
    elsif ($a eq '--cache')  { $cache_arg = shift @ARGV; }
    elsif ($a eq '--strict') { $strict = 1; }
    else { die "unknown argument $a\n"; }
}
$root =~ s{\\}{/}g; $game =~ s{\\}{/}g; $cache_arg =~ s{\\}{/}g;

my (@errors, @warnings);
sub err  { push @errors,   shift; }
sub warnx { push @warnings, shift; }

# ---------------------------------------------------------------- vanilla keys
my %vanilla;
my $cache = $cache_arg || "$root/tools/cache/vanilla_script_keys.txt";
if (open my $fh, '<', $cache) {
    while (<$fh>) { chomp; $vanilla{$_} = 1; }
    close $fh;
} else {
    warnx("no vanilla key cache at $cache - vocabulary check disabled (run tools/validate.sh once to build it)");
}
# every dotted / prefixed segment seen anywhere in vanilla
my %segment;
for my $k (keys %vanilla) {
    for my $s (split /[.:]/, $k) { $segment{$s} = 1 if length $s; }
}

# ---------------------------------------------------------------- collect files
my @files;
for my $d ("$root/in_game", "$root/main_menu", "$root/loading_screen") {
    next unless -d $d;
    find({ no_chdir => 1, wanted => sub { push @files, $File::Find::name if -f $_ && /\.(txt|yml|gui|info|json)$/i } }, $d);
}
@files = sort @files;

# ---------------------------------------------------------------- helpers
sub read_file {
    my ($path) = @_;
    open my $fh, '<:raw', $path or do { err("cannot read $path"); return (undef, 0) };
    local $/; my $raw = <$fh>; close $fh;
    my $bom = ($raw =~ s/^\xEF\xBB\xBF//) ? 1 : 0;
    utf8::decode($raw) or warnx("$path: not valid UTF-8");
    return ($raw, $bom);
}

# strip comments and strings so braces/keys can be analysed; keeps line structure
sub strip_script {
    my ($text) = @_;
    my @out;
    for my $line (split /\n/, $text, -1) {
        my $clean = '';
        my $in_str = 0;
        my @chars = split //, $line;
        for (my $i = 0; $i < @chars; $i++) {
            my $c = $chars[$i];
            if ($in_str) {
                if ($c eq '\\' && $i + 1 < @chars) { $i++; next; }
                if ($c eq '"') { $in_str = 0; $clean .= '"'; }
                next;
            }
            if ($c eq '"') { $in_str = 1; $clean .= '"'; next; }
            if ($c eq '#') { last; }
            $clean .= $c;
        }
        push @out, $clean;
    }
    return join "\n", @out;
}

# ---------------------------------------------------------------- pass 1: mod-defined keys
my %moddef;
my %modloc; # loc keys defined by the mod
for my $f (@files) {
    my ($text, $bom) = read_file($f);
    next unless defined $text;
    if ($f =~ /\.yml$/i) {
        for my $line (split /\n/, $text) {
            if ($line =~ /^\s*([A-Za-z0-9_.\-]+):\d*\s*"/) { $modloc{$1} = 1; }
        }
        next;
    }
    next unless $f =~ /\.txt$/i;
    my $clean = strip_script($text);
    for my $line (split /\n/, $clean) {
        if ($line =~ /^([A-Za-z_][\w.]*)\s*=/) { $moddef{$1} = 1; }          # top-level definitions
    }
    # event ids: namespace.N
    while ($clean =~ /^\s*([a-z_][\w]*\.\d+)\s*=\s*\{/mg) { $moddef{$1} = 1; }
    # game rule settings are nested one level below the rule key (rule = { setting = { ... } })
    if ($f =~ m{/game_rules/}) { while ($clean =~ /^\s+([a-z_][\w]*)\s*=\s*\{/mg) { $moddef{$1} = 1; } }
}

# ---------------------------------------------------------------- pass 2: per-file checks
my %unknown;
for my $f (@files) {
    my ($text, $bom) = read_file($f);
    next unless defined $text;
    my $rel = $f; $rel =~ s{^\Q$root\E/?}{};

    if ($f =~ /\.(txt|yml)$/i && !$bom) { warnx("$rel: missing UTF-8 BOM (vanilla files have one)"); }

    if ($f =~ /\.yml$/i) {
        my ($lang) = $f =~ /_l_([a-z_]+)\.yml$/i;
        my @lines = split /\n/, $text;
        my ($first) = grep { /\S/ } @lines;
        if (!defined $lang) { err("$rel: localization file name must end with _l_<language>.yml"); }
        elsif (!defined $first || $first !~ /^\s*l_\Q$lang\E:\s*$/) { err("$rel: first line must be 'l_$lang:'"); }
        my %seen; my $n = 0;
        for my $line (@lines) {
            $n++;
            next if $line =~ /^\s*#/ || $line !~ /\S/ || $n == 1;
            if ($line =~ /^\s*([A-Za-z0-9_.\-]+):\d*\s*(".*)$/) {
                my ($k, $v) = ($1, $2);
                warnx("$rel:$n: duplicate loc key $k") if $seen{$k}++;
                my $q = () = $v =~ /(?<!\\)"/g;
                err("$rel:$n: unbalanced quotes") if $q % 2;
            } else {
                warnx("$rel:$n: line is not 'key:0 \"text\"'");
            }
        }
        next;
    }

    if ($f =~ /\.(txt|gui)$/i) {
        my $clean = strip_script($text);
        my $open  = () = $clean =~ /\{/g;
        my $close = () = $clean =~ /\}/g;
        err("$rel: brace mismatch ($open '{' vs $close '}')") if $open != $close;
        # unbalanced quotes per line (after comment removal only)
        my $n = 0;
        for my $line (split /\n/, $text) {
            $n++;
            my $l = $line; $l =~ s/#.*// unless $l =~ /"[^"]*#[^"]*"/;
            my $q = () = $l =~ /(?<!\\)"/g;
            warnx("$rel:$n: odd number of quotes") if $q % 2;
        }
    }

    if ($f =~ /\.gui$/i) {
        while ($text =~ /texture\s*=\s*"([^"]+\.dds)"/g) {
            my $p = $1;
            next if $p =~ /\[/;      # data function
            my $ok = 0;
            for my $base ("$root/in_game", "$root/main_menu", "$root/loading_screen", "$game/game/in_game", "$game/game/main_menu", "$game/game/loading_screen", "$game/jomini/in_game", "$game/jomini/main_menu", "$game/jomini/loading_screen", "$game/clausewitz/main_menu", "$game/clausewitz/loading_screen") {
                if (-f "$base/$p") { $ok = 1; last; }
            }
            warnx("$rel: texture not found: $p") unless $ok;
        }
        next;
    }

    next unless $f =~ /\.txt$/i && %vanilla;
    next if $rel =~ m{(^|/)localization/};
    my $clean = strip_script($text);
    my $n = 0;
    for my $line (split /\n/, $clean) {
        $n++;
        next unless $line =~ /^\s*([A-Za-z_][\w.:\$]*)\s*(=|<|>|>=|<=|!=|\?=)/;
        my $k = $1;
        next if $k =~ /\$/;                        # scripted-effect argument placeholder
        next if $vanilla{$k} || $moddef{$k};
        if ($k =~ /[.:]/) {
            my @segs = split /[.:]/, $k;
            my @bad = grep { !$segment{$_} && !$moddef{$_} } @segs;
            # the part after a prefix like unit_type:, modifier:, c:, flag:, var: is user data
            @bad = () if @segs == 2 && $segment{$segs[0]} && $segs[0] =~ /^(unit_type|modifier|c|flag|var|scope|local_var|global_var|event_target|continent|sub_continent|area|region|province|location|culture|religion|static_modifier|unit_category|age|government_reform|subject_type|ai_personality|trait|advance|law|policy|decision|building_type|goods|pop_type|estate|international_organization|character|dynasty|country|war|location_rank|casus_belli|wargoal|peace_treaty)$/;
            next unless @bad;
            $k = join('/', @bad) . " (in $k)";
        }
        push @{ $unknown{$k} }, "$rel:$n";
    }
}

for my $k (sort keys %unknown) {
    my @w = @{ $unknown{$k} };
    my $where = join(', ', @w[0..($#w > 2 ? 2 : $#w)]) . (@w > 3 ? " (+".(@w-3)." more)" : '');
    warnx("unknown key '$k' not found in vanilla scripts nor defined by the mod: $where");
}

# ---------------------------------------------------------------- report
binmode STDOUT, ':utf8';
print "Validated ", scalar(@files), " files under $root\n";
print "\nERRORS (", scalar(@errors), "):\n"; print "  $_\n" for @errors;
print "\nWARNINGS (", scalar(@warnings), "):\n"; print "  $_\n" for @warnings;
print "\nRESULT: ", (@errors ? "FAIL" : "OK"), "\n";
exit 1 if @errors;
exit 2 if $strict && @warnings;
exit 0;
