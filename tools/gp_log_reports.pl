#!/usr/bin/perl
# tools/gp_log_reports.pl - the mod's yearly GP_REPORT blocks of debug.log, tagged with the game year.
#
#   perl tools/gp_log_reports.pl LOGS_DIR [OUT_DIR]
#
# Needs OUT_DIR/newyear.tsv from tools/gp_log_timeline.pl (run that first). debug.log contains binary bytes - this
# script reads it raw. Writes reports.tsv: year, TAG, Name, time, "line1 | line2 | ..." (one row per country per
# report block). Also reads GP_WAR blocks (v0.12.1: one block per declared war, printed on on_war_declared) into
# war_blocks.tsv: year, time, "line1 | line2 | ...".  Both formats are the plain debug_log lines of
# in_game/common/scripted_effects/gp_effects.txt (gp_debug_report) and gp_pressure_effects.txt.
use strict; use warnings;

my $dir = shift or die "usage: perl tools/gp_log_reports.pl LOGS_DIR [OUT_DIR]\n";
my $out = shift // $dir;

sub secs { my ($h, $m, $s) = @_; my $t = $h * 3600 + $m * 60 + $s; $t += 86400 if $h < 12; return $t; }

my @ny;
open(my $m, '<', "$out/newyear.tsv") or die "run tools/gp_log_timeline.pl first ($out/newyear.tsv missing)\n";
while (<$m>) { chomp; my ($t, $y) = split /\t/; push @ny, [$t, $y]; }
close $m;
sub year_at { my $t = shift; my $y = 1337; for my $e (@ny) { last if $e->[0] > $t; $y = $e->[1]; } return $y; }

open(my $d, '<:raw', "$dir/debug.log") or die "cannot open $dir/debug.log: $!";
my ($cur, $curyear, $curt, @lines, @blocks, @wblocks, $wcur, @wlines, $wyear, $wt);
sub flush_rep { push @blocks, [$curyear, $cur->[0], $cur->[1], $curt, join(" | ", @lines)] if $cur; $cur = undef; @lines = (); }
sub flush_war { push @wblocks, [$wyear, $wt, join(" | ", @wlines)] if $wcur; $wcur = 0; @wlines = (); }
while (<$d>) {
	if (/^\[(\d\d):(\d\d):(\d\d)\]\[[^\]]+\]: [^ ]+\.txt:\d+: GP_REPORT (.*?)\s*$/) {
		my ($h, $mi, $s, $txt) = ($1, $2, $3, $4);
		my $t = secs($h, $mi, $s);
		if ($txt =~ /^([A-Z][A-Z0-9_]{2,}) (.+)$/) { flush_rep(); $cur = [$1, $2]; $curyear = year_at($t); $curt = "$h:$mi:$s"; }
		elsif ($txt =~ /^game start/) { flush_rep(); }
		else { $txt =~ s/^\s+//; push @lines, $txt if $cur; }
	}
	elsif (/^\[(\d\d):(\d\d):(\d\d)\]\[[^\]]+\]: [^ ]+\.txt:\d+: GP_WAR (.*?)\s*$/) {
		my ($h, $mi, $s, $txt) = ($1, $2, $3, $4);
		my $t = secs($h, $mi, $s);
		if ($txt =~ /^declared\b/ || $txt =~ /^war /) { flush_war(); $wcur = 1; $wyear = year_at($t); $wt = "$h:$mi:$s"; }
		$txt =~ s/^\s+//; push @wlines, $txt if $wcur;
	}
}
flush_rep(); flush_war();
close $d;

open(my $o, '>:raw', "$out/reports.tsv") or die;
print $o join("\t", @$_), "\n" for @blocks;
close $o;
open(my $wo, '>:raw', "$out/war_blocks.tsv") or die;
print $wo join("\t", @$_), "\n" for @wblocks;
close $wo;
printf "report blocks: %d, war blocks: %d\n", scalar(@blocks), scalar(@wblocks);
