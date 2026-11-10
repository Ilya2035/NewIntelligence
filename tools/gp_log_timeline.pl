#!/usr/bin/perl
# tools/gp_log_timeline.pl - year-tagged event timeline of an EU5 observation game (Geopolicy).
#
#   perl tools/gp_log_timeline.pl LOGS_DIR [OUT_DIR]
#
# Reads LOGS_DIR/game.log (a COPY of the logs - the game truncates them at the next start) and writes into OUT_DIR
# (default LOGS_DIR): newyear.tsv (session seconds -> year), timeline.tsv (year, hh:mm:ss, source, text) with the war /
# civil war / disaster / colony / exploration / situation lines, wars.tsv (year, time, attacker, target) for every
# "WAR: X declared war on Y" line. The game log has no game dates, but it prints "NEW YEAR: <year>" once a year; the
# year of any log line is the last NEW YEAR mark before it (lines before the first mark belong to 1337).
# Times are real clock times; a game that crosses midnight is handled (hours < 12 count as the next day).
# Names are the localised country names as printed by the game (Russian in the author's install). No Python needed.
use strict; use warnings;

my $dir = shift or die "usage: perl tools/gp_log_timeline.pl LOGS_DIR [OUT_DIR]\n";
my $out = shift // $dir;

sub secs { my ($h, $m, $s) = @_; my $t = $h * 3600 + $m * 60 + $s; $t += 86400 if $h < 12; return $t; }

my @ny;    # [secs, year]
open(my $g, '<:raw', "$dir/game.log") or die "cannot open $dir/game.log: $!";
while (<$g>) {
	push @ny, [secs($1, $2, $3), $4] if /^\[(\d\d):(\d\d):(\d\d)\]\[gamestate\.cpp:\d+\]: NEW YEAR: (\d+)/;
}
close $g;
sub year_at { my $t = shift; my $y = 1337; for my $e (@ny) { last if $e->[0] > $t; $y = $e->[1]; } return $y; }

my @ev;
open($g, '<:raw', "$dir/game.log") or die;
while (<$g>) {
	next unless /^\[(\d\d):(\d\d):(\d\d)\]\[([A-Za-z0-9_]+\.cpp):\d+\]: (.*)$/;
	my ($h, $m, $s, $src, $txt) = ($1, $2, $3, $4, $5);
	next unless $src =~ /^(diplomatic_action_war|rebel_manager|country|colony_manager|situation_manager|exploration)\.cpp$/;
	$txt =~ s/\s+$//;
	push @ev, [secs($h, $m, $s), "$h:$m:$s", $src, $txt];
}
close $g;

open(my $o, '>:raw', "$out/timeline.tsv") or die;
open(my $w, '>:raw', "$out/wars.tsv") or die;
for my $e (sort { $a->[0] <=> $b->[0] } @ev) {
	my $y = year_at($e->[0]);
	(my $src = $e->[2]) =~ s/\.cpp//;
	print $o join("\t", $y, $e->[1], $src, $e->[3]), "\n";
	print $w "$y\t$e->[1]\t$1\t$2\n" if $e->[3] =~ /^WAR: (.+?) declared war on (.+?)\s*$/;
}
close $o; close $w;
open(my $m, '>', "$out/newyear.tsv") or die;
print $m "$_->[0]\t$_->[1]\n" for @ny;
close $m;
printf "events: %d, new-year marks: %d (first %s, last %s)\n", scalar(@ev), scalar(@ny),
	(@ny ? $ny[0][1] : '-'), (@ny ? $ny[-1][1] : '-');
