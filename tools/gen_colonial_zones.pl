#!/usr/bin/perl
# New Intelligence: Geopolicy - generator of the colonial zones (v0.11).
# Reads the zone table below and the vanilla map (in_game/map_data/definitions.txt), writes:
#   mods/new_intelligence_geopolicy/in_game/common/scripted_effects/gp_colonial_zones.txt   (setup of the zones)
#   mods/new_intelligence_geopolicy/in_game/common/customizable_localization/gp_colonial_zones.txt (zone names)
#   <scratch>/gp_cz_loc_{russian,english}.yml  (loc lines to paste into gp_geopolicy_l_*.yml)
# Run from Git Bash:  perl tools/gen_colonial_zones.pl [scratch dir]
# A zone = a list of vanilla areas and/or regions. Its anchor is the first land location of its first area: every land
# location of the zone gets var:gp_cz_anchor = the anchor, and the anchor carries the zone data (id, flags, leader).
# Flags: nw = New World (colonial right applies), asia = Asian zone (overreach count), africa = African coast;
# g1..g6 = open to the limited colonial right of that group (gp_colonies.txt: g1 Scandinavia, g2 the Low Countries,
# g3 Iberia, g4 Britain, g5 France, g6 the German and Baltic lands).
use strict;
use warnings;
use utf8;
binmode STDOUT, ':utf8';

my $game = $ENV{EU5_GAME_DIR} || '/c/Program Files (x86)/Steam/steamapps/common/Europa Universalis V';
my $scratch = shift @ARGV || '.';
my $mod = 'mods/new_intelligence_geopolicy';

# id | key | flags | areas/regions (region keys end in _region) | RU name | EN name
my @zones = (
 [1,'cuba','nw g3','cuba_area','Куба','Cuba'],
 [2,'hispaniola','nw g3','hispaniola_area','Эспаньола','Hispaniola'],
 [3,'lesser_antilles','nw g2 g3 g4 g5 g6','lesser_antilles_area','Малые Антилы','Lesser Antilles'],
 [4,'new_france','nw g5','quebec_area laurentian_area lower_canada_area eastern_ontario_area western_ontario_area','Новая Франция','New France'],
 [5,'acadia','nw g1 g4 g5','newfoundland_area prince_edward_island_area acadia_area new_brunswick_area','Акадия и Ньюфаундленд','Acadia and Newfoundland'],
 [6,'hudson','nw g1','jamesie_area nunavik_area labrador_area northern_ontario_area northwestern_ontario_area greenstone_belt_area keewatin_area keewatin_n_area james_bay_lowlands_area','Гудзонов залив и Лабрадор','Hudson Bay and Labrador'],
 [7,'new_england','nw g4','massachusetts_area southern_new_england_area vermont_area new_hampshire_area maine_area','Новая Англия','New England'],
 [8,'new_netherland','nw g2','hudson_area haudenosaunee_area new_jersey_area pennsylvania_area westsylvania_area','Новые Нидерланды','New Netherland'],
 [9,'virginia','nw','maryland_area virginia_area west_virginia_area north_carolina_area south_carolina_area georgia_us_area','Виргиния и Каролины','Virginia and the Carolinas'],
 [10,'the_south','nw','florida_area tennessee_area kentucky_area alabama_area mississippi_area','Юг и Флорида','The South and Florida'],
 [11,'great_lakes','nw','ohio_area indiana_area michigan_area illinois_area wisconsin_area','Огайо и Великие озёра','Ohio and the Great Lakes'],
 [12,'louisiana','nw','louisiana_area arkansas_area missouri_area iowa_area','Луизиана','Louisiana'],
 [13,'great_plains','nw','superior_area badlands_area upper_missouri_area central_plains_area high_plains_area saskatchewan_area red_river_area','Великие равнины','The Great Plains'],
 [14,'texas','nw','texas_area tamaulipeco_area natahende_area shiewhibak_area tahejoc_area','Техас и северная граница','Texas and the northern frontier'],
 [15,'new_spain','nw','mexihko_area huaxyacac_area tochtepec_area tlaxcala_area michoacan_area xilotepec_area chilapan_area mayaab_area puuk_area chactemal_area xalisco_area culiacan_area zacatecas_area guachichil_area','Новая Испания','New Spain'],
 [16,'california','nw','california_area baja_area great_basin_area','Калифорния','California'],
 [17,'cascadia','nw','cascadia_area rockies_area columbia_interior_area','Орегон','Oregon'],
 [18,'alaska','nw','northwest_coast_area western_arctic_area alaxsxaq_area yukon_area athabasca_area','Аляска и северо-запад','Alaska and the north-west'],
 [19,'central_america','nw','peten_area tezulutlan_area kuskatan_area imabite_area nekokiaw_area panama_area','Центральная Америка','Central America'],
 [20,'new_granada','nw','boiaca_area sinu_area suchiimma_area caracas_area orinucu_area apure_area chunsa_area caly_area','Новая Гранада','New Granada'],
 [21,'guiana','nw g2 g5','guayana_area','Гвиана','Guiana'],
 [22,'peru','nw','quitu_area chala_area yunga_area puna_area qullaw_area acamama_area suni_area rupa_rupa_area galapagos_area','Перу','Peru'],
 [23,'chile','nw','atacama_area cuyo_area ngulumapu_area juan_fernandez_area','Чили','Chile'],
 [24,'brazil','nw g3','brazil_region','Бразилия','Brazil'],
 [25,'la_plata','nw','la_plata_region chaco_region','Ла-Плата','La Plata'],
 [26,'australia','nw','australia_region','Австралия','Australia'],
 [27,'new_zealand','nw','new_zealand_region','Новая Зеландия','New Zealand'],
 [28,'new_guinea','nw','bismarck_area momase_area kerema_area milne_area wanin_area papua_area anim_ha_area','Новая Гвинея','New Guinea'],
 [29,'india_nw','asia','hindustan_region western_india_region','Северо-Западная Индия','North-West India'],
 [30,'india_south','asia','deccan_region central_india_region','Южная Индия','South India'],
 [31,'bengal','asia','bengal_region','Бенгалия','Bengal'],
 [32,'indochina','asia','indochina_region','Индокитай','Indochina'],
 [33,'east_indies','asia','south_borneo_area north_borneo_area celebes_area java_area lesser_sunda_area moluccas_area south_sumatra_area north_sumatra_area','Ост-Индия','The East Indies'],
 [34,'philippines','asia','luzon_area mindanao_area visayas_area','Филиппины','The Philippines'],
 [35,'china','asia','east_china_region north_china_region south_china_region west_china_region','Китай','China'],
 [36,'japan','asia','japan_region korea_region','Япония и Корея','Japan and Korea'],
 [37,'guinea_coast','africa','guinea_region','Гвинейский берег','The Guinea Coast'],
 [38,'kongo','africa','kongo_region','Конго и Ангола','Kongo and Angola'],
 [39,'cape','africa g2','southern_africa_region','Капская земля','The Cape'],
 [40,'swahili','africa','swahili_coast_region','Суахили и Мозамбик','The Swahili Coast and Mozambique'],
);

# ---- read the map: region -> areas, area -> first land location ----
open my $fh, '<:encoding(UTF-8)', "$game/game/in_game/map_data/definitions.txt" or die "map not found: $!";
my (%region_areas, %area_first, %area_region);
my ($region, $area) = ('', '');
while (my $line = <$fh>) {
	if ($line =~ /^\t\t([a-z_]+_region) = \{/) { $region = $1; next; }
	if ($line =~ /^\t\t\t([a-z_0-9]+) = \{/) { $area = $1; push @{$region_areas{$region}}, $area; $area_region{$area} = $region; next; }
	if ($area && !$area_first{$area} && ($line =~ /^\t\t\t\t[a-z_0-9]+ = \{(.*)/ || $line =~ /^\t\t\t\t\t([a-z_0-9 ]+)\s*$/)) {
		my $rest = $1;
		$rest =~ s/not_eligible_for_dynamic_country_name = yes//;
		$rest =~ s/[{}]//g;
		my @locs = grep { /^[a-z_0-9]+$/ } split /\s+/, $rest;
		$area_first{$area} = $locs[0] if @locs;
	}
}
close $fh;

my $out = "\x{FEFF}###################################\n";
$out .= "# New Intelligence: Geopolicy - colonial zones (v0.11). GENERATED by tools/gen_colonial_zones.pl - edit the table there.\n";
$out .= "# gp_cz_setup (global, once): every land location of a zone gets var:gp_cz_anchor = the zone's anchor location; the\n";
$out .= "# anchor gets var:gp_cz_id, the flags gp_cz_nw / gp_cz_asia / gp_cz_africa / gp_cz_g1..g6 and joins the global list\n";
$out .= "# gp_cz_anchors. The yearly zone pass (gp_col_world_update, gp_colonies.txt) stores the leader and the shares on the anchor.\n";
$out .= "###################################\n\n";
$out .= "gp_cz_setup = {\n\tif = {\n\t\tlimit = { NOT = { has_global_variable = gp_cz_ready } }\n\t\tset_global_variable = gp_cz_ready\n";
$out .= "\t\tgp_cz_setup_$_->[0] = yes\n" for @zones;
$out .= "\t\tgp_col_africa_setup = yes\n\t}\n}\n\n";

my ($cl, $ru, $en) = ('', '', '');
for my $z (@zones) {
	my ($id, $key, $flags, $list, $rn, $enn) = @$z;
	my @parts = split /\s+/, $list;
	my $first_area = $parts[0] =~ /_region$/ ? $region_areas{$parts[0]}[0] : $parts[0];
	die "unknown area/region $parts[0] in zone $key\n" unless $first_area && exists $area_first{$first_area};
	my $anchor = $area_first{$first_area};
	$out .= "# $id $key - $enn (anchor $anchor)\ngp_cz_setup_$id = {\n";
	$out .= "\tlocation:$anchor = {\n\t\tset_variable = { name = gp_cz_id value = $id }\n";
	$out .= "\t\tset_variable = gp_cz_$_\n" for split /\s+/, $flags;
	$out .= "\t\tadd_to_global_variable_list = { name = gp_cz_anchors target = this }\n\t}\n";
	for my $p (@parts) {
		if ($p =~ /_region$/) {
			die "unknown region $p\n" unless $region_areas{$p};
			$out .= "\tregion:$p = { every_location_in_region = { limit = { is_land = yes } set_variable = { name = gp_cz_anchor value = location:$anchor } } }\n";
		} else {
			die "unknown area $p\n" unless exists $area_region{$p};
			$out .= "\tarea:$p = { every_location_in_area = { limit = { is_land = yes } set_variable = { name = gp_cz_anchor value = location:$anchor } } }\n";
		}
	}
	$out .= "}\n\n";
	$cl .= "\ttext = {\n\t\tlocalization_key = gp_cz_$key\n\t\ttrigger = { var:gp_cz_id ?= $id }\n\t}\n";
	$ru .= " gp_cz_$key: \"$rn\"\n";
	$en .= " gp_cz_$key: \"$enn\"\n";
}

open my $o1, '>:encoding(UTF-8)', "$mod/in_game/common/scripted_effects/gp_colonial_zones.txt" or die $!;
print $o1 $out; close $o1;

open my $o2, '>:encoding(UTF-8)', "$mod/in_game/common/customizable_localization/gp_colonial_zones.txt" or die $!;
print $o2 "\x{FEFF}###################################\n# New Intelligence: Geopolicy - names of the colonial zones (v0.11). GENERATED by tools/gen_colonial_zones.pl.\n";
print $o2 "# Scope: the zone's anchor location ([Location.Custom('gp_cz_name')]; from any location of a zone:\n# [Location.MakeScope.Var('gp_cz_anchor').GetLocation.Custom('gp_cz_name')]).\n###################################\n\n";
print $o2 "gp_cz_name = {\n\ttype = location\n\tlog_loc_errors = yes\n\n$cl\ttext = {\n\t\tlocalization_key = gp_cz_none\n\t}\n}\n";
close $o2;

open my $o3, '>:encoding(UTF-8)', "$scratch/gp_cz_loc_russian.yml" or die $!; print $o3 $ru; close $o3;
open my $o4, '>:encoding(UTF-8)', "$scratch/gp_cz_loc_english.yml" or die $!; print $o4 $en; close $o4;
print scalar(@zones), " zones written\n";
