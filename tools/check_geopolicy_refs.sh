#!/usr/bin/env bash
# Run from Git Bash:  bash tools/check_geopolicy_refs.sh
# Cross-checks every map / culture / religion / location / tag reference of the Geopolicy mod against the game files:
#   * area = X / region = X and areas { } / regions { } lists in gp_zones.txt and gp_formables.txt -> map_data/definitions.txt
#   * location:X, culture:X, culture_group:X, religion_group:X, sub_continent:X, continent:X -> their vanilla databases
#   * tags of the zone switches (gp_zone_effects.txt) -> setup/countries (warning only: formable tags are not set up there)
# Complements tools/validate.sh (which checks script KEYS, not the values they point at).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME="${EU5_GAME_DIR:-/c/Program Files (x86)/Steam/steamapps/common/Europa Universalis V}"
MOD="$HERE/mods/new_intelligence_geopolicy"
[ -d "$MOD" ] || { echo "mod folder not found: $MOD"; exit 1; }
[ -d "$GAME/game" ] || { echo "game folder not found: $GAME (set EU5_GAME_DIR)"; exit 1; }

perl - "$GAME" "$MOD" <<'PERL'
use strict; use warnings;
use File::Glob ':bsd_glob';	# the game path contains spaces: plain glob() would split the pattern on them
my ($game,$mod) = @ARGV;
my $errors = 0; my $warnings = 0;
sub slurp { my $f = shift; local $/; open my $h, '<', $f or die "$f: $!"; my $t = <$h>; close $h; $t =~ s/^\xEF\xBB\xBF//; $t =~ s/#.*//mg; return $t; }

# --- map hierarchy ---------------------------------------------------------------------------------
my %kind; # name -> continent / sub_continent / region / area / province / location
{
	my $t = slurp("$game/game/in_game/map_data/definitions.txt");
	my @toks = $t =~ /([A-Za-z0-9_\-\.]+|\{|\})/g;
	my @path; my $pending;
	my @levels = qw(continent sub_continent region area province);
	for my $tk (@toks) {
		if ($tk eq '{') { push @path, $pending; $kind{$pending} //= $levels[$#path] if defined $pending && $#path <= 4; $pending = undef; next }
		if ($tk eq '}') { pop @path; $pending = undef; next }
		if (@path == 5) { $kind{$tk} //= 'location' }
		$pending = $tk;
	}
}
# --- vanilla databases -----------------------------------------------------------------------------
sub keys_of { my ($dir, $re) = @_; my %k; for my $f (glob("$dir/*.txt")) { my $t = slurp($f); while ($t =~ /^([a-z_0-9]+)\s*=\s*\{/mg) { $k{$1} = 1 } } return \%k; }
my $cultures = keys_of("$game/game/in_game/common/cultures");
my $culture_groups = keys_of("$game/game/in_game/common/culture_groups");
my $religion_groups = keys_of("$game/game/in_game/common/religion_groups");
my %tags; for my $f (glob("$game/game/in_game/setup/countries/*.txt")) { my $t = slurp($f); while ($t =~ /^([A-Z0-9]{3})\s*=\s*\{/mg) { $tags{$1} = 1 } }
# the formable's own tag sits at one-tab indentation ("\ttag = GAE"); "tag = ENG" inside potential = { } is deeper
my %formable_tags; { my $t = slurp("$mod/in_game/common/formable_countries/gp_formables.txt"); while ($t =~ /^\ttag\s*=\s*([A-Z0-9]{3})\s*$/mg) { $formable_tags{$1} = 1 } }

sub check { my ($file, $what, $name, $ok, $hint) = @_; return if $ok; $errors++; print "ERROR  $file: unknown $what '$name'$hint\n"; }

# --- area / region references --------------------------------------------------------------------
for my $rel ('in_game/common/area_preferences/gp_zones.txt', 'in_game/common/formable_countries/gp_formables.txt', 'in_game/common/scripted_triggers/gp_triggers.txt', 'in_game/common/scripted_effects/gp_zone_effects.txt', 'in_game/common/ai_scripted_expansion_score/gp_expansion_scores.txt') {
	my $f = "$mod/$rel"; next unless -f $f; my $t = slurp($f); my $short = $rel; $short =~ s{.*/}{};
	# "area = x" / "region = x" data lines; scope links such as "region = scope:gp_self.capital.region" are skipped
	while ($t =~ /^\s*area\s*=\s*([a-z_0-9]+)(?![:.a-z_0-9])/mg) { check($short, 'area', $1, ($kind{$1}//'') eq 'area', '') }
	while ($t =~ /^\s*region\s*=\s*([a-z_0-9]+)(?![:.a-z_0-9])/mg) { next if $1 =~ /^(scope|root|prev|this|var)$/; check($short, 'region', $1, ($kind{$1}//'') eq 'region', '') }
	while ($t =~ /\b(areas|regions|provinces)\s*=\s*\{([^}]*)\}/g) {
		my ($list, $body) = ($1, $2); my $want = $list eq 'areas' ? 'area' : $list eq 'regions' ? 'region' : 'province';
		for my $n ($body =~ /([a-z_0-9]+)/g) { check($short, $want, $n, ($kind{$n}//'') eq $want, '') }
	}
	while ($t =~ /\b(region|area|sub_continent|continent):([a-z_0-9]+)/g) { check($short, $1, $2, ($kind{$2}//'') eq $1, '') }
	while ($t =~ /\blocation:([a-z_0-9]+)/g) { check($short, 'location', $1, ($kind{$1}//'') eq 'location', '') }
	while ($t =~ /\bculture:([a-z_0-9]+)/g) { check($short, 'culture', $1, $cultures->{$1}, '') }
	while ($t =~ /\bculture_group:([a-z_0-9]+)/g) { check($short, 'culture_group', $1, $culture_groups->{$1}, '') }
	while ($t =~ /\breligion_group:([a-z_0-9]+)/g) { check($short, 'religion_group', $1, $religion_groups->{$1} || $1 eq 'christian' || $1 eq 'muslim', '') }
}
# --- tags of the zone switches ----------------------------------------------------------------------
{
	my $t = slurp("$mod/in_game/common/scripted_effects/gp_zone_effects.txt");
	my %seen;
	while ($t =~ /^\s*([A-Z0-9]{3})\s*=\s*\{\s*gp_(?:add|remove)_pref/mg) { $seen{$1} = 1 }
	for my $tag (sort keys %seen) {
		next if $tags{$tag} || $formable_tags{$tag};
		my $vanilla_formable = `grep -c "tag = $tag\\b" "$game/game/in_game/common/formable_countries/00_formable_countries.txt" 2>/dev/null`; chomp $vanilla_formable;
		next if $vanilla_formable > 0;
		$warnings++; print "WARN   gp_zone_effects.txt: tag '$tag' is neither set up in setup/countries nor a known formable tag\n";
	}
	# every preference named in the switches must exist in gp_zones.txt and vice versa
	my $z = slurp("$mod/in_game/common/area_preferences/gp_zones.txt");
	my %defined; while ($z =~ /^(gp_[a-z_0-9]+)\s*=\s*\{/mg) { $defined{$1} = 1 }
	my %used; while ($t =~ /PREF\s*=\s*(gp_[a-z_0-9]+)/g) { $used{$1} = 1 }
	for my $p (sort keys %used) { next if $defined{$p}; $errors++; print "ERROR  gp_zone_effects.txt: preference '$p' is not defined in gp_zones.txt\n" }
	for my $p (sort keys %defined) { next if $used{$p} || $p eq 'gp_generic_home_region' || $p eq 'gp_colonial_home_region' || $p eq 'gp_colonial_ambition' || $p =~ /^gp_dir_/; $warnings++; print "WARN   gp_zones.txt: preference '$p' is defined but never assigned\n" }
}
# --- loc coverage of the preferences / formables / modifiers -----------------------------------------
{
	my $loc = ''; for my $f (glob("$mod/main_menu/localization/english/*.yml")) { local $/; open my $h, '<', $f; $loc .= <$h>; close $h }
	my %lockeys; while ($loc =~ /^\s([A-Za-z_0-9.]+):/mg) { $lockeys{$1} = 1 }
	my $z = slurp("$mod/in_game/common/area_preferences/gp_zones.txt");
	while ($z =~ /^(gp_[a-z_0-9]+)\s*=\s*\{/mg) { next if $lockeys{$1}; $warnings++; print "WARN   loc: no English name for area preference '$1'\n" }
	my $fm = slurp("$mod/in_game/common/formable_countries/gp_formables.txt");
	while ($fm =~ /^(gp_[a-z_0-9]+_f)\s*=\s*\{/mg) { for my $k ($1, "$1_desc") { next if $lockeys{$k}; $errors++; print "ERROR  loc: missing '$k'\n" } }
	# a formable may reuse a vanilla tag (gp_commonwealth_f forms the vanilla PLC): its name may come from vanilla loc
	my $vloc = ''; for my $f (glob("$game/game/main_menu/localization/english/*.yml")) { $vloc .= slurp($f) }
	for my $tag (sort keys %formable_tags) { for my $k ($tag, "${tag}_ADJ") { next if $lockeys{$k} || $vloc =~ /^\s+\Q$k\E:/m; $errors++; print "ERROR  loc: missing '$k'\n" } }
	# country modifiers were removed on 2026-11-04 (no buffs); check them only if such a file comes back
	my $smf = "$mod/main_menu/common/static_modifiers/gp_country_modifiers.txt";
	my $sm = -f $smf ? slurp($smf) : "";
	while ($sm =~ /^(gp_[a-z_0-9]+)\s*=\s*\{/mg) { for my $k ("STATIC_MODIFIER_NAME_$1", "STATIC_MODIFIER_DESC_$1") { next if $lockeys{$k}; $errors++; print "ERROR  loc: missing '$k'\n" } }
	# coat of arms for every formable tag
	my $coa = ''; for my $f (glob("$mod/main_menu/common/coat_of_arms/coat_of_arms/*.txt")) { $coa .= slurp($f) }
	# arms are looked up by each formable's flag key, in the mod or in vanilla (gp_great_hungary_f uses flag = HUN)
	my $vcoa = ''; for my $f (glob("$game/game/main_menu/common/coat_of_arms/coat_of_arms/*.txt")) { $vcoa .= slurp($f) }
	while ($fm =~ /^\s*flag\s*=\s*([A-Z0-9_]+)/mg) { my $fl = $1; next if $coa =~ /^\Q$fl\E\s*=\s*\{/m || $vcoa =~ /^\Q$fl\E\s*=\s*\{/m; $errors++; print "ERROR  coat_of_arms: no arms for flag '$fl'\n" }
	my $colors = slurp("$mod/main_menu/common/named_colors/gp_colors.txt");
	for my $f (glob("$game/game/main_menu/common/named_colors/*.txt")) { $colors .= slurp($f) }
	while ($fm =~ /^\s*color\s*=\s*(map_[A-Za-z0-9_]+)/mg) { next if $colors =~ /\b\Q$1\E\s*=/; $errors++; print "ERROR  named_colors: missing '$1'\n" }
	# emblem textures used by the arms exist
	my $texdir = "$game/game/main_menu/gfx/coat_of_arms";
	while ($coa =~ /texture\s*=\s*"([^"]+)"/g) { my $tx = $1; my $sub = $tx =~ /^ce_/ ? 'colored_emblems' : $tx =~ /^te_/ ? 'textured_emblems' : 'patterns'; next if -f "$texdir/$sub/$tx"; $errors++; print "ERROR  coat_of_arms: texture '$tx' not found in $sub\n" }
	while ($coa =~ /pattern\s*=\s*"([^"]+)"/g) { next if -f "$texdir/patterns/$1"; $errors++; print "ERROR  coat_of_arms: pattern '$1' not found\n" }
}
print "check_geopolicy_refs: $errors error(s), $warnings warning(s)\n";
exit($errors ? 1 : 0);
PERL
