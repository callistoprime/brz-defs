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
use Data::IEEE754 qw( pack_float_be unpack_float_be );

use File::Basename qw( fileparse );

die "Usage: $0 ./ZA1Jxxxx.xml ./ZA1Jxxxx.bin ./ZA1Jxxxx-addresses.csv [writes out-ZA1Jxxxx.xml]" unless @ARGV == 3;

state %types2d = (
    0 => 'FLOAT',  # 2d
    4 => 'BYTE',   # 2dm
    8 => 'USHORT', # 2dm
);

state %types3d = (
            0 => 'UNDEFINED', # 3d
     67108864 => 'BYTE', # 3dm
    134217728 => 'USHORT', # 3dm
);

sub warnlevel :prototype($$);
sub normalize_address;

my $rr = XML::LibXML->load_xml(location => $ARGV[0]) or die "load_xml: $!";
my \%addrs = csv(in => $ARGV[2], key => 'name', escape_char => '\\') or die "csv: $!";

open my $za1j, '<:raw', $ARGV[1] or die "open za1j: $!";
die "za1j fail: $!" unless read $a = $za1j, $za1j, 1310720, 0;
die "za1j len != 1310720" unless length($za1j) == 1310720;

sub byte    ($from) { return unpack('C', $from); }
sub ushort  ($from) { return unpack('n', $from); }
sub dword   ($from) { return unpack('N', $from); }

sub unhex   ($from) {
    if (length($from) == 0) {
        die "no length";
    } elsif (length($from) == 2) {
        $from =~ /^([a-z0-9]{2})$/;
        die "fail byte: $1" unless length("$1") == 2;
        my(@bytes) = map { chr hex $_ } ($1);
        die "fail byte 2: @bytes" unless (grep { defined $_ } @bytes) == 1;
        return join('', @bytes);
    } elsif (length($from) == 4) {
        $from =~ /^([a-z0-9]{2})([a-z0-9]{2})$/;
        die "fail word: $1 $2" unless length("$1$2") == 4;
        my(@bytes) = map { chr hex $_ } ($1, $2);
        die "fail word 2: @bytes" unless (grep { defined $_ } @bytes) == 2;
        return join('', @bytes);
    } elsif (length($from) == 8) {
        $from =~ /^([a-z0-9]{2})([a-z0-9]{2})([a-z0-9]{2})([a-z0-9]{2})$/;
        die "fail dword: $1 $2 $3 $4" unless length("$1$2$3$4") == 8;
        my(@bytes) = map { chr hex $_ } ($1, $2, $3, $4);
        die "fail dword 2: @bytes" unless (grep { defined $_ } @bytes) == 4;
        return join('', @bytes);
    } else {
        die "unknown length";
    }
}

sub hexaddr ($from) {
    $from = sprintf '%x', $from;
    #$from = substr('00000000' . $from, -8, 8);
    return $from;
}

my $rom0 = ($rr->findnodes('/roms/rom'))[0] or die "no rom0";

for my $t (sort { $a->{'name'} cmp $b->{'name'} } values %addrs) {
    my \%t = $t;
    if ($t{'type2'} eq 'synth2D') {
        my $r_tbl = $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']")->[0] or die "synth2d lookup fail: $t{'name'}";
        my $r_addr = $r_tbl->getAttribute('storageaddress'); my $m_addr = 0;
        if ($r_addr ne $t{'data'}) {
            warn "synth2d address mismatch: $t{'name'} -- $r_addr ne $t{'data'}";
            $m_addr = 1;
        }
        if ($m_addr) {
            $r_tbl->setAttribute('storageaddress' => $t{'data'});
        }
        say "# synth2d ok? $t{'name'} \[$t{'sizey'}\] \@ $t{'data'}";
        next;
    }
    next unless $t{'type'} =~ /^(?:2D|3D)$/;
    my($tabletype, $addr, $xsize, $type, $xaxis, $ysize, $yaxis, $data, $scale, $offset, @notes);
    $addr  = dword unhex substr('00000000' . $t{'table'}, -8, 8);
    $xsize = ushort substr($za1j, $addr + 0, 2);
    $xaxis = hexaddr dword substr($za1j, $addr + 4, 4);
    if (length($xaxis) > 6) {
        push @notes, 'xaxis was not a pointer';
        undef $xaxis; undef $xsize;
    } elsif ($xsize >= 256) {
        push @notes, 'xsize was too large';
        undef $xaxis; undef $xsize;
    } else {
        $ysize = ushort substr($za1j, $addr + 2, 2);
        if ($t{'type2'} eq '3D' and $ysize > 0) {
            $yaxis = hexaddr dword substr($za1j, $addr + 8, 4);
            $data  = hexaddr dword substr($za1j, $addr + 12, 4);
            $type  = dword substr($za1j, $addr + 16, 4);
            if (not(defined $yaxis) or not(defined $ysize) or (length($yaxis) == 0) or ($ysize == 0)) {
                push @notes, 'yaxis was not loaded successfully';
                undef $xaxis; undef $xsize; undef $yaxis; undef $ysize; undef $type; undef $data;
            } else {
                if ($type > 0) {
                    push @notes, $tabletype = '3dmtable';
                    $scale  = unpack "f>", substr($za1j, $addr + 20, 4);
                    $offset = unpack "f>", substr($za1j, $addr + 24, 4);
                } else {
                    push @notes, $tabletype = '3dtable';
                }
                if ($t{'type'} eq '2D') {
                    push @notes, 'RR defined as 2D!';
                    undef $tabletype;
                }
            }
        } elsif ($t{'type2'} eq '2D') { # 2D
            $type  = byte   substr($za1j, $addr + 2, 1);
            $ysize = byte   substr($za1j, $addr + 3, 1);
            $data  = hexaddr dword substr($za1j, $addr + 8, 4);
            if (length($data) > 6) {
                push @notes, 'data was not a pointer';
                undef $xaxis; undef $xsize; undef $yaxis; undef $ysize; undef $type; undef $data;
            } elsif ($ysize > 0 and not length($yaxis) > 0) {
                push @notes, 'ysize/yaxis mismatch';
                undef $xaxis; undef $xsize; undef $yaxis; undef $ysize; undef $type; undef $data;
            } else {
                if ($type > 0) {
                    push @notes, $tabletype = '2dmtable';
                    $scale  = unpack "f>", substr($za1j, $addr + 12, 4);
                    $offset = unpack "f>", substr($za1j, $addr + 16, 4);
                } else {
                    push @notes, $tabletype = '2dtable';
                }
                if ($t{'type'} eq '3D') {
                    push @notes, 'RR defined as 3D!';
                    undef $tabletype;
                }
            }
        } else { # unhandled
            say "# unhandled table: $t{'name'} ($t{'type2'})";
        }
    }
    if (not(defined $yaxis) and ($ysize // 0) > 0) {
        push @notes, '3d stored in 2d';
    }
    my $notes = (@notes > 0) ? join(', ', @notes) : '';
    print "$t{'name'} ($t{'table'}) ";
    print "x=$xaxis\[$xsize\] " if ($xsize // 0) > 0 or defined($xaxis);
    print "y=$yaxis\[$ysize\] " if ($ysize // 0) > 0 or defined($yaxis);
    if (length($data // '') > 0) {
        print "data=$data";
        if ($ysize > 0) {
            print "[${xsize}x${ysize}] ";
        } else {
            print "[$xsize] ";
        }
        if (($scale // 1) ne 1) {
            print "* $scale ";
        }
        if (($offset // 0) ne 0) {
            print "+ $offset ";
        }
    }
    print "(type $type=" . ((defined($yaxis) ? $types3d{$type} : $types2d{$type}) // 'UNKNOWN') . ") " if length($type // '') > 0;
    print "-- $notes" if length($notes // '') > 0;
    print "\n";
    if (($xsize//0) > 0 and not defined($xaxis)) { die "unhandled 1" }
    if (not(($xsize//0) > 0) and defined($xaxis)) { die "unhandled 2" }
    if (($ysize//0) > 0 and not defined($yaxis)) { die "unhandled 3" }
    if (not(($ysize//0) > 0) and defined($yaxis)) { die "unhandled 4" }
    my $node = $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']") or die "not found";

    $tabletype //= 'unknown';
    if ($tabletype =~ /^2d/) {

        my($r_data) = $node->[0]->getAttribute('storageaddress'); my $m_data = 0;
        if ($r_data ne $data) {
            $r_data = $data;
            $m_data = 1;
        }

        # romraider swaps Y and X size on 2D tables, so we swap them at load because 100% error rate otherwise.

        my($r_xsize) = $node->[0]->getAttribute('sizey'); my $m_xsize = 0;
        if (not(defined $r_xsize) or $r_xsize != $xsize) {
            $r_xsize = $rr->findnodes("//roms/rom[2]/table[\@name='$t{'name'}']")->[0]->getAttribute('sizey');
            $m_xsize = 1;
        }

        my($r_xtbl) = $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']/table[\@type='Y Axis']")->[0]; my($m_xtbl) = 0;
        if (not defined $r_xtbl) {
            $r_xtbl = $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']/table[\@type='X Axis']")->[0];
            die "r_xtbl not found in either X or Y axis!" if not defined $r_xtbl;
            $m_xtbl = 1;
        }

        my($r_xaxis) = $r_xtbl->getAttribute('storageaddress'); my $m_xaxis = 0;
        if ($r_xaxis ne $xaxis) {
            $m_xaxis = 1;
        }

        if ($m_data) {
            $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']")->[0]->setAttribute(storageaddress => $data);
        }
        if ($m_xsize) {
            $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']")->[0]->setAttribute(sizey => $xsize);
        }
        if ($m_xtbl) {
            $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']/table[\@type='X Axis']")->[0]->setAttribute(type => 'Y Axis');
        }
        if ($m_xaxis) {
            $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']/table[\@type='Y Axis']")->[0]->setAttribute(storageaddress => $xaxis);
        }

    } elsif ($tabletype =~ /^3d/) {

        my($r_data) = $node->[0]->getAttribute('storageaddress'); my $m_data = 0;
        if ($r_data ne $data) {
            $r_data = $data;
            $m_data = 1;
        }

        # romraider does NOT swap Y and X on 3d tables, so we don't swap them at load here.

        my($r_xsize) = $node->[0]->getAttribute('sizex'); my($m_xsize) = 0;
        if (not(defined $r_xsize) or $r_xsize != $xsize) {
            $r_xsize = $rr->findnodes("//roms/rom[2]/table[\@name='$t{'name'}']")->[0]->getAttribute('sizex');
            $m_xsize = 1;
        }

        my($r_ysize) = $node->[0]->getAttribute('sizey'); my($m_ysize) = 0;
        if (not(defined $r_ysize) or $r_ysize != $ysize) {
            $r_ysize = $rr->findnodes("//roms/rom[2]/table[\@name='$t{'name'}']")->[0]->getAttribute('sizey');
            $m_ysize = 1;
        }

        my($r_xtbl) = $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']/table[\@type='X Axis']")->[0];
        die "r_xtbl not found in X axis" if not defined $r_xtbl;

        my($r_xaxis) = $r_xtbl->getAttribute('storageaddress'); my $m_xaxis = 0;
        if ($r_xaxis ne $xaxis) {
            $m_xaxis = 1;
        }

        my($r_ytbl) = $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']/table[\@type='Y Axis']")->[0];
        die "r_ytbl not found in Y axis" if not defined $r_ytbl;

        my($r_yaxis) = $r_ytbl->getAttribute('storageaddress'); my $m_yaxis = 0;
        if ($r_yaxis ne $yaxis) {
            $m_yaxis = 1;
        }

        if ($m_data) {
            $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']")->[0]->setAttribute(storageaddress => $data);
        }
        if ($m_xsize) {
            $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']")->[0]->setAttribute(sizex => $xsize);
        }
        if ($m_ysize) {
            $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']")->[0]->setAttribute(sizey => $ysize);
        }
        if ($m_xaxis) {
            $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']/table[\@type='X Axis']")->[0]->setAttribute(storageaddress => $xaxis);
        }
        if ($m_yaxis) {
            $rr->findnodes("//roms/rom[1]/table[\@name='$t{'name'}']/table[\@type='Y Axis']")->[0]->setAttribute(storageaddress => $yaxis);
        }

    } else {
        print "# unhandled table: $t{'name'}\n";
    }

    if ($tabletype =~ /^[23]dm?table/) {
        my($r_scaling) = $rr->findnodes("//roms/rom[2]/table[\@name='$t{'name'}']/scaling")->[0];

        my($expr, $to_byte);
        if ($tabletype =~ /^.dmtable/) {
            # try to deal with percentages
            if ($r_scaling->getAttribute('units') =~ /\%/) {
                $scale *= 100;
                $offset *= 100;
            }

            # turn it into a decimal, truncate at 20 places (zero is up around 40)
            $scale = sprintf('%.20f', $scale);
            $offset = sprintf('%.20f', $offset);

            # FIXME: deal with 2dtable_short
            if ($scale =~ /^0(\.0+)?$/) {
                # bail out for 2dtable_short for now
                $expr = 'x';
                $to_byte = 'x';
            } else {
                # strip trailing zeroes
                $scale =~ s/\.0+$//; $scale =~ s/(?<=[^0])0+$// if $scale =~ /\./;
                $offset =~ s/\.0+$//; $offset =~ s/(?<=[^0])0+$// if $offset =~ /\./;

                # scales of 1 and offsets of 0 don't need to be expressed
                my($has_scale) = (0+$scale) != 1;
                my($has_offset) = (0+$offset) != 0;

                # strip leading zeroes
                $scale =~ s/^0\././;
                $offset =~ s/^0\././;

                # construct the unpack/pack functions for RR scaling
                $expr    = ($has_scale ? ($has_offset ? "(x*$scale)" : "x*$scale") : 'x') . ($has_offset ? ($offset < 0 ? "$offset" : "+$offset") : '');
                $to_byte = ($has_offset ? ($has_scale ? '(' : '') . 'x' . ($offset < 0 ? "+" . (-1*$offset) : "-$offset") . ($has_scale ? ')' : '') : 'x') . ($has_scale ? "/$scale" : '');

                # fix sign/operator overlaps to maintain parity with existing RR defs
                $expr =~ s/\)\+-/\)\-/;
                $to_byte =~ s/x--/x+/;
            }
        } else {
            $expr = 'x';
            $to_byte = 'x';
        }
        my($r_expr)    = $r_scaling->getAttribute('expression'); my $m_expr = 0;
        if ($r_expr ne $expr) {
            $r_expr =~ s/([\*\/])0\./$1./;
            if ($r_expr ne $expr) {
                $m_expr = 1;
            }
        }
        my($r_to_byte) = $r_scaling->getAttribute('to_byte'); my $m_to_byte = 0;
        if ($r_to_byte ne $to_byte) {
            $r_to_byte =~ s/([\*\/])0\./$1./;
            if ($r_to_byte ne $to_byte) {
                $m_to_byte = 1;
            }
        }

        if ($m_expr) {
            $r_scaling->setAttribute(expression => $expr);
        }
        if ($m_to_byte) {
            $r_scaling->setAttribute(to_byte => $to_byte);
        }
    }
}

my($fn) = (fileparse $ARGV[0])[0];
open(my $out, '>', "out-$fn") or die "open: $!";
binmode($out);
$rr->toFH($out);
close($out) or die "close: $!";
