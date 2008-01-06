#!perl
# $Id: /mirror/perl/Text-MeCab/trunk/tools/probe_mecab.pl 38046 2008-01-06T12:44:20.889262Z daisuke  $
#
# Copyright (c) 2006 Daisuke Maki <dmaki@cpan.org>
# All rights reserved.

use strict;
use File::Spec;

my $interactive = -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT)) ;
my($version, $cflags, $libs);

$cflags = '';

# Save the poor puppies that run on Windows
if ($^O eq 'MSWin32') {
    print <<EOM;
You seem to be running on an environment that may not have mecab-config
available. This script uses mecab-config to auto-probe 
  1. The version string of libmecab that you are building Text::MeCab
     against. (e.g. 0.90)
  2. Additional compiler flags that you may have built libmecab with, and
  3. Additional linker flags that you may have build libmecab with.

Since we can't auto-probe, you should specify the above three to proceed
with compilation:
EOM

    print "Version of libmecab that you are compiling against (e.g. 0.90)? (REQUIRED) [] ";
    $version = <STDIN>;
    chomp($version);
    die "no version specified! cowardly refusing to proceed." unless $version;

    print "Additional compiler flags (e.g. -DWIN32 -Ic:\\path\\to\\mecab\\sdk)? [] ";
    if ($interactive) {
        $cflags = <STDIN>;
        chomp($cflags);
    }

    print "Additional linker flags (e.g. -lc:\\path\\to\\mecab\\sdk\\libmecab.lib? [] ";
    if ($interactive) {
        $libs = <STDIN>;
        chomp($libs);
    }
} else {
    # try probing in places where we expect it to be
    my $mecab_config;
    foreach my $path qw(/usr/bin /usr/local/bin) {
        my $tmp = File::Spec->catfile($path, 'mecab-config');
        if (-f $tmp && -x _) {
            $mecab_config = $tmp;
            last;
        }
    }
    
    print "Path to mecab config? [$mecab_config] ";
    if ($interactive) {
        my $tmp = <STDIN>;
        chomp $tmp;
        if ($tmp) {
            $mecab_config = $tmp;
        }
    }
    
    if (!-f $mecab_config || ! -x _) {
        print STDERR "Can't proceed without mecab-config. Aborting...\n";
        exit 1;
    }
    
    $version = `$mecab_config --version`;
    chomp $version;

    $cflags = `$mecab_config --cflags`;
    chomp($cflags);

    $libs   = `$mecab_config --libs`;
    chomp($libs);
}

print "detected mecab version $version\n";
if ($version < 0.90) {
    print " + mecab version < 0.90 doesn't contain some of the features\n",
          " + that are available in Text::MeCab. Please read the documentation\n",
          " + carefully before using\n";
}

my($major, $minor, $micro) = map { s/\D+//g; $_ } split(/\./, $version);

$cflags .= " -DMECAB_MAJOR_VERSION=$major -DMECAB_MINOR_VERSION=$minor";

# remove whitespaces from beginning and ending of strings
$cflags =~ s/^\s+//;
$cflags =~ s/\s+$//;

print "Using compiler flags '$cflags'...\n";

if ($libs) {
    $libs =~ s/^\s+//;
    $libs =~ s/\s+$//;
    print "Using linker flags '$libs'...\n";
} else {
    print "No linker flags specified\n";
}

my $encoding = 'utf-8';
print 
    "Text::MeCab needs to know what encoding you built your dictionary with\n",
    "to properly execute tests.\n",
    "\n",
    "Encoding of your mecab dictionary? (shift_jis, euc-jp, utf-8) [$encoding] "
;

if ($interactive) {
    my $input = <STDIN>;
    chomp $input;
    if ($input) {
        $encoding = $input;
    }
}

my $encoding_ok = 1;
if (! eval { require Encode }) {
    $encoding_ok = 0;
    print 
        "!!! WARNING !!!\n",
        "\n",
        "We were unable to load Encode.pm to convert the test data to $encoding.\n",
        "This may result in a test failure if you are using a dictionary encoding\n",
        "other than euc-jp.\n\n"
    ;
}

my %data = (
    taro => "太郎は次郎が持っている本を花子に渡した。",
    sumomo => "すもももももももものうち。"
);
if ($encoding_ok) {
    foreach my $key (keys %data) {
        Encode::from_to($data{$key}, 'euc-jp', $encoding);
    }
}

open my $fh, '>', 't/strings.dat';
if (eval { require Data::Dump }) {
    print $fh Data::Dump::dump(\%data);
} elsif (eval { require Data::Dumper }) {
    local $Data::Dumper::Indent   = 1;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Terse    = 1;
    print $fh Data::Dumper::Dumper(\%data);
} else {
    print
        "Couldn't load Data::Dump or Data::Dumper!\n",
        "Refusing to proceed\n";
    exit 1;
}
close $fh;

print "Using $encoding as your dictionary encoding\n";

return { version => $version, cflags => $cflags, libs => $libs, encoding => $encoding };