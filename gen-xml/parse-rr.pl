#!/usr/bin/env perl
use v5.42.0; use strict; use warnings; use utf8; use open ':std', ':encoding(UTF-8)';

use feature 'declared_refs'; no warnings "experimental::declared_refs";
use feature 'refaliasing'; no warnings "experimental::refaliasing";

use Text::ANSI::WideUtil qw( ta_mbsubstr );
use List::Util qw( uniq any all );
use Log::ger::Output Screen => (
    color_depth => 16777216,
    colorize_tags => 1,
);
use Log::ger::Layout Pattern => (
    format => '%m (%p)',
);
use Log::ger; use Log::ger::Util;
Log::ger::Util::set_level('error');
use Text::CSV qw( csv );
use XML::LibXML;

sub warnlevel :prototype($$);
sub normalize_address;

die "Usage: $0 ./ZA1Jxxxx.xml ./ZA1Jxxxx.bin ./ZA1Jxxxx-symbols.csv ./ZA1Jxxxx-2dmtable.txt ./ZA1Jxxxx-3dmtable.txt\n" unless @ARGV == 5;

my $rr = XML::LibXML->load_xml(location => $ARGV[0]) or die "load_xml: $!";
my @rom = $rr->findnodes('/roms/rom') or die "rom: $!";
my $romid = ($rom[0]->getChildrenByTagName('romid'))[0] or die "romid: $!";
# declare and abort if there are any table attributes we don't know about yet.
my @attrs = grep { state $r = sprintf '^(%s)$', join '|', qw( name type storageaddress sizex sizey storagetype endian category userlevel logparam ); $_ !~ /$r/o; } uniq map { $_->nodeName } $rr->findnodes("/roms/rom/table/@*");
die "unrecognized table attributes: @attrs" if @attrs > 0;
my $xmlid = $romid->getChildrenByTagName('xmlid')->to_literal() or die "xmlid: $!";
die "first romid is not Zx1Jxxxx*" unless $xmlid =~ /^Z.1J[A-Z0-9]{4,}$/;
say "# parsing $xmlid";

my %tables; my %tablenames;
my \%ts = $tables{'*'} //= {}; my \@ts = $tablenames{'*'} //= [];
my \%t0 = $tables{'0'} //= {}; my \@t0 = $tablenames{'0'} //= [];
my \%t1 = $tables{'1'} //= {}; my \@t1 = $tablenames{'1'} //= [];

for my $r (0..$#rom) {
    for my $e (map { $_->childNodes } $rom[$r]) {
        next unless $e->nodeName eq 'table';
        my $name = $e->getAttribute('name') or die "unnamed table";

        # the order of appearance is important for generating the document later on
        push @{$tablenames{$r} ||= []}, $name unless exists $tables{$r}{$name};
        my \%t = $tables{$r}{$name} //= {};

        # the first instance of an attribute takes precedence over later ones;
        # so, we use //= here to ensure we never overwrite an existing one, even if empty.
        map { my $v = $e->getAttribute($_); $t{$_} //= $v if defined $v; }
            qw( storageaddress sizex sizey type category );
    }
}

for my $r (0..$#rom) {
    for my $name (@{$tablenames{$r}}) {
        push @ts, $name unless exists $ts{$name};
        my \%t = $ts{$name} //= {};
        map { $t{$_} //= $tables{$r}{$name}{$_} } keys %{ $tables{$r}{$name} };
        $ts{$name}{'name'} //= $name;
    }
}

map { normalize_address(\$_->{'storageaddress'}) } grep { exists $_->{'storageaddress'} } map { $ts{$_} } @ts;
my %tableaddrs;
my \%ta = $tableaddrs{'*'} //= {};
map { my $address = $_->{'storageaddress'}; $ta{$address} //= []; push(@{$ta{$address}}, $_); } grep { exists $_->{'storageaddress'} } values %ts;

for my $name (@{$tablenames{'*'}}) {
    my(\%car, \%def) = map { $_->{$name} // {} } @tables{0,1};
    # do we declare a storage address in the defs?
    log_error "[01] def $name has a storageaddress!" if exists $def{'storageaddress'};
    # do we declare an address in the car without the sizes from the def?
    log_info "[02] car $name is missing sizex/y from def!" if exists $car{'storageaddress'} and any { exists $def{$_} and $def{$_} > 1 and not exists $car{$_} } qw( sizex sizey );
    # do we have a car entry without a def?
    log_error "[03] def $name is missing for car!" if defined $tables{0}{$name} and not defined $tables{1}{$name};
    # do we declare a sizex/sizey in the car and the def?
    log_info "[04] both $name have the same size!" if all { exists $tables{$_}{$name} } (0,1) and any { exists $car{$_} and exists $def{$_} and ($car{$_} // 1) eq ($def{$_} // 1) } qw( sizex sizey );
    # do the car and def have *different* sizes?
    log_warn "[05] both $name have different sizes!" if all { exists $tables{$_}{$name} } (0,1) and any { exists $car{$_} and exists $def{$_} and ($car{$_} // 1) ne ($def{$_} // 1) } qw( sizex sizey );
}

my \%gh_vars = csv(in => $ARGV[2], key => 'Name', value => 'Location', escape_char => '\\') or die "csv: $!";
map { normalize_address \$gh_vars{$_} } keys %gh_vars;
my %gh_addrs;
map { $a = $_; push(@{$gh_addrs{$gh_vars{$a}} //= []}, $a) } keys %gh_vars;
my \%gh_types = csv(in => $ARGV[2], key => 'Location', value => 'Code Unit', escape_char => '\\') or die "csv2: $!";
map { $a = $_; normalize_address \$a; $gh_types{$a} = delete $gh_types{$_} if $a ne $_; } keys %gh_types;

sub normalize_address ($address) {
    die "normalize_address requires scalar refs" unless ref($address);
    \$a = $address;
    $a = lc $a;
    $a =~ s/ //g;
    $a =~ s/^0+(?=[^0]|$)//;
}

my %tablelabels;
my \%tl = \%tablelabels;
for my \%entry (@ts{ grep { exists $ts{$_}{'storageaddress'} } @ts }) {
    my($name, $address) = @entry{qw( name storageaddress )};
    # do we have xml addresses that aren't labeled in Ghidra?
    if (not exists $gh_addrs{$address}) {
        log_warn "[10] entry $name has unlabeled address $address!";
    } else {
        my \@labels = $gh_addrs{$address};
        if (@labels > 1) {
            log_info "[11] entry $name has multiple $address labels!" if exists $gh_addrs{$address};
        }
        for my $l (0..$#labels) {
            $a = $name; $a =~ s/[\#\(\)\/\.\_\-]/ /g; $a =~ s/(?<=[^ ]) {2,}(?! )/ /g; $a =~ s/(?<=[^ ]) +$//;
            $b = $labels[$l]; $b =~ s/[\#\(\)\/\.\_\-]/ /g; $b =~ s/(?<=[^ ]) {2,}(?! )/ /g; $b =~ s/(?<=[^ ]) +$//;
            state @rewrites = (
                [ 'Columns' => 'Cols' ],
                [ 'Compensations?(?:Limits?)?' => 'Comp' ],
                [ 'ActivationThreshold' => 'Activation' ],
                [ 'Thresh?holds?' => 'Thresh' ],
                [ 'Determination' => 'Determ' ],
                [ 'Minimum' => 'Min' ],
                [ 'Maximum' => 'Max' ],
                [ '^Tipin' => 'ThrottleTipin' ],
                [ 'Pulsewidth' => 'Pw' ],
                [ 'CoolantTemperature' => 'ECT' ],
                [ 'IntakeAirTemperature' => 'IAT' ],
                [ 'AdvanceMapValue' => 'Advance' ],
            );
            map { $a =~ s/$_->[0]/$_->[1]/ig; $b =~ s/$_->[0]/$_->[1]/ig; } @rewrites;
            my $matched = 0;
            $matched++ if lc $a eq lc $b;
            $matched++ if lc "$a data" eq lc $b;
            $matched++ if lc "$a yaxis" eq lc $b;
            $a = $name; $a =~ s/[\#\(\)\/\.\_\- ]//g;
            $b = $labels[$l]; $b =~ s/[\#\(\)\/\.\_\- ]//g;
            map { $a =~ s/$_->[0]/$_->[1]/ig; $b =~ s/$_->[0]/$_->[1]/ig; } @rewrites;
            $matched++ if lc $a eq lc $b;
            $matched++ if lc "$a data" eq lc $b;
            $matched++ if lc "$a yaxis" eq lc $b;
            push @{$tl{$name} //= []}, $labels[$l] if $matched;
        }
        log_error "[12] address $address has mismatched labels! <<< $name !>> ".join(', ', @labels) unless exists $tl{$name};
    }
}

open my $za1j, '<:raw', $ARGV[1] or die "open za1j: $!";
die "za1j fail: $!" unless read $a = $za1j, $za1j, 1310720, 0;
die "za1j len != 1310720" unless length($za1j) == 1310720;

sub type_generalize ($type) {
    return $type unless defined $type;
    $type =~ s/ .*$//;
    $type =~ s/\[\d+\]/\[#\]/g;
    $type =~ s/undefined\d+$/undefined#/g;
    return $type;
}

my %typecount;
map { $typecount{type_generalize $gh_types{$_}}++ } keys %gh_types;
say "types found: @>> ".join(' ', sort keys %typecount);

open my $table2d, '<', $ARGV[3] or die "open 2dm: $!";
my %table2d;
while (<$table2d>) {
    state($name, $base, $xsize, $xaxis, $data);
    if (not(defined $name) and /^ +([^ ]+)(?:$| +XREF)/) {
        $name = $1;
        next;
    }
    if (/^\s+([0-9a-f]{8})[\s0-9a-f]+2dm?table$/) {
        $base = $1;
        normalize_address \$base;
        next;
    }
    if (/^\s+[0-9a-f]{8}[\s0-9a-f]+short\s+(\d+)\s+xsize/) {
        $xsize = $1;
        next;
    }
    if (/^\s+[0-9a-f]{8}\s+([0-9a-f]{2} [0-9a-f]{2} [0-9a-f]{2} [0-9a-f]{2}).*xaxis/) {
        $xaxis = $1;
        normalize_address \$xaxis;
        next;
    }
    if (/^\s+[0-9a-f]{8}\s+([0-9a-f]{2} [0-9a-f]{2} [0-9a-f]{2} [0-9a-f]{2}).*data(?!\S)/) {
        $data = $1;
        normalize_address \$data;
        $table2d{$base} = {
            name => $name,
            base => $base,
            xsize => $xsize,
            xaxis => $xaxis,
            data => $data,
        };
        undef $name; undef $base; undef $xsize; undef $xaxis; undef $data;
        next;
    }
}

open my $table3d, '<', $ARGV[4] or die "open 3dm: $!";
my %table3d;
while (<$table3d>) {
    state($name, $base, $xsize, $ysize, $xaxis, $yaxis, $data);
    if (not(defined $name) and /^ +([^ ]+)(?:$| +XREF)/) {
        $name = $1;
        next;
    }
    if (/^\s+([0-9a-f]{8})[\s0-9a-f]+3dm?table$/) {
        $base = $1;
        normalize_address \$base;
        next;
    }
    if (/^\s+[0-9a-f]{8}[\s0-9a-f]+short\s+(\d+)\s+xsize/) {
        $xsize = $1;
        next;
    }
    if (/^\s+[0-9a-f]{8}[\s0-9a-f]+short\s+(\d+)\s+ysize/) {
        $ysize = $1;
        next;
    }
    if (/^\s+[0-9a-f]{8}\s+([0-9a-f]{2} [0-9a-f]{2} [0-9a-f]{2} [0-9a-f]{2}).*xaxis/) {
        $xaxis = $1;
        normalize_address \$xaxis;
        next;
    }
    if (/^\s+[0-9a-f]{8}\s+([0-9a-f]{2} [0-9a-f]{2} [0-9a-f]{2} [0-9a-f]{2}).*yaxis/) {
        $yaxis = $1;
        normalize_address \$yaxis;
        next;
    }
    if (/^\s+[0-9a-f]{8}\s+([0-9a-f]{2} [0-9a-f]{2} [0-9a-f]{2} [0-9a-f]{2}).*data(?!\S)/) {
        $data = $1;
        normalize_address \$data;
        $table3d{$base} = {
            name => $name,
            base => $base,
            xsize => $xsize,
            ysize => $ysize,
            xaxis => $xaxis,
            yaxis => $yaxis,
            data => $data,
        };
        undef $name; undef $base; undef $xsize; undef $ysize; undef $xaxis; undef $yaxis; undef $data;
        next;
    }
}

my %axis_sizes;
for my $t (uniq map { $_->{'xaxis'} } values %table3d) {
    my(@xsizes) = uniq map { $_->{'xsize'} } grep { $_->{'xaxis'} eq $t } (values(%table3d), values(%table2d));
    die "xsize?!" unless @xsizes > 0;
    log_error "[31] xaxis $t has multiple xsizes << @xsizes >>" if @xsizes > 1;
    my(@ysizes) = uniq map { $_->{'ysize'} } grep { $_->{'yaxis'} eq $t } values %table3d;
    log_error "[32] xaxis $t has multiple ysizes << @ysizes >>" if @ysizes > 1;
    my(@sizes) = uniq (@xsizes, @ysizes);
    log_error "[33] xaxis $t has multiple sizes << @sizes >>" if @sizes > 1;
    $axis_sizes{$t} = 0+$sizes[0] if @sizes == 1;
}
for my $t (uniq map { $_->{'yaxis'} } values %table3d) {
    my(@xsizes) = uniq map { $_->{'xsize'} } grep { $_->{'xaxis'} eq $t } (values(%table3d), values(%table2d));
    log_error "[31] yaxis $t has multiple xsizes << @xsizes >>" if @xsizes > 1;
    my(@ysizes) = uniq map { $_->{'ysize'} } grep { $_->{'yaxis'} eq $t } values %table3d;
    die "ysize?!" unless @ysizes > 0;
    log_error "[32] yaxis $t has multiple ysizes << @ysizes >>" if @ysizes > 1;
    my(@sizes) = uniq (@xsizes, @ysizes);
    log_error "[33] xaxis $t has multiple sizes << @sizes >>" if @sizes > 1;
    $axis_sizes{$t} = 0+$sizes[0] if @sizes == 1;
}

say join("\t", qw( name dataaddr tableaddr sizey sizex type category ));
for my $tn (@{$tablenames{'*'}}) {
    my \%t = $tables{'*'}{$tn};
    my $tn = $tn; $tn =~ s/ /_/g;
    $t{'tableaddress'} = $gh_vars{$tn} if exists $gh_vars{$tn};
    say join("\t", map { $_ // '' } @t{qw( name storageaddress tableaddress sizey sizex type category )});
}
exit 0;

for my \%table (map { @{$_} } values %ta) {
    my($name, $address, $sizey, $sizex) = @table{qw( name storageaddress sizey sizex )};
    my $typeraw = $gh_types{$address};
    my $type = type_generalize $typeraw;
    my \@labels = $gh_addrs{$address} // [];
    if (@labels == 0) {
        log_warn "[21] $address $name has no label!";
    }
    if (not defined $type or not length $type) {
        log_info "[22] type for $address is invalid?!";
    } elsif ($type =~ /(?:\?|undef)/) {
        log_error "[23] address $address has undefined type! << @labels";
    } else {
        log_warn "[27] unhandled type $type at $address for $name";
    }
    # count the params; no matter what type they are, the sizex/y should match
    if (defined $type) {
        if ($type =~ /^[a-z]+\[#\]$/) {
            $typeraw =~ /\[(\d+)\]/;
            log_error "[24] $address $type mismatch between xml and ghidra! << $1 != $sizey >>" if $1 != $sizey;
        } elsif ($type =~ /^[a-z]+\[#\]\[#\]$/) {
            $typeraw =~ /\[(\d+)\]\[(\d+)\]/;
            log_error "[25] $address $type mismatch between xml and ghidra! << $1 != $sizex >>" if $1 != $sizex;
            log_error "[26] $address $type mismatch between xml and ghidra! << $2 != $sizey >>" if $2 != $sizey;
        }
    }
    # check for axis mismatches in the 3dmtable defs, too
    my %tables_checked;
    for my $table (grep { $_->{xaxis} eq $address } values(%table3d)) {
        my($tname, $tbase, $txsize, $tysize, $tdata) = @{$table}{qw( name base xsize ysize data )};
        log_error "[27] $address size $sizex count mismatch with table $tbase xsize $txsize" if $sizex != $txsize;
        $tables_checked{$tname}++;
    }
    for my $table (grep { $_->{yaxis} eq $address } values %table3d) {
        my($tname, $tbase, $txsize, $tysize, $tdata) = @{$table}{qw( name base xsize ysize data )};
        log_error "[27] $address size $sizey count mismatch with table $tbase ysize $tysize" if $sizey != $tysize;
        $tables_checked{$tname}++;
    }
    for my $table (grep { $_->{data} eq $address } values %table3d) {
        my($tname, $tbase, $txsize, $tysize, $tdata) = @{$table}{qw( name base xsize ysize data )};
        log_error "[28] $address size $sizex x $sizey mismatch with table $tbase $txsize x $tysize" if $sizex != $txsize or $sizey != $tysize;
        $tables_checked{$tname}++;
    }
    for my $table (grep { $_->{xaxis} eq $address } values %table2d) {
        my($tname, $tbase, $txsize, $tdata) = @{$table}{qw( name base xsize data )};
        log_error "[27] $address size $sizey mismatch with table $tbase $txsize" if $sizey != $txsize;
        $tables_checked{$tname}++;
    }
    for my $table (grep { $_->{data} eq $address } values %table2d) {
        my($tname, $tbase, $txsize, $tdata) = @{$table}{qw( name base xsize data )};
        if (defined $sizex) {
            # either we have an artificial 3d table in the xml but it's flattened in the ecu
            # or we have a wildly corrupt table def
            my $size = $sizex * $sizey;
            if ($size == $txsize) {
                log_debug "[29] $address size $sizex x $sizey = $size assumed to be 3d-ified of 2dtable $tbase $txsize";
            } else {
                log_error "[28] $address size $sizex x $sizey = $size mismatch with table $tbase $txsize" if $sizey != $txsize;
            }
        } else {
            log_error "[28] $address size $sizey mismatch with table $tbase $txsize" if $sizey != $txsize;
        }
        $tables_checked{$tname}++;
    }
    my $tables_checked = keys %tables_checked;
    if ($tables_checked > 0) {
        if (defined($type) and $type !~ /\[/) {
            log_error "[2d] $address $name <$type> found in $tables_checked tables?! << ".join(' ', sort keys %tables_checked)." >>";
        } else {
            log_debug "[2a] $address $name found in $tables_checked tables << ".join(' ', sort keys %tables_checked)." >>";
        }
    } else {
        if (defined($type) and $type =~ /\[/) {
            $typeraw =~ /(?<!\])\[(\d+)\](\[(\d+)\])?(?!\[)/;
            if (defined $2) {
                log_error "[2b] $address $type [$1 x $2] not found in any tables!";
            } else {
                log_error "[2b] $address $type [$1] not found in any tables!";
            }
        } else {
            log_info "[2c] $address not found in any tables.";
        }
    }
    if ((not(defined $sizex) or $sizex == 1) and ($sizey == 1) and (not(defined $type) or $type =~ /(?:\?|undef)/)) {
        log_info "[2e] $address is a single value but has no defined type! ($name)";
    }
    # TODO: pick up the types from the XML and start cross-checking them
}
