#!/usr/bin/perl -w

#
# Program Summary:
#
# Name:             install.pl
# Description:      installs dailystrips
# Author:           Andrew Medico <amedico@amedico.dhs.org>
# Created:          13 Jul 2000, 11:34 EST
# Last Modified:    15 July 2001 16:05 EST
# Current Revision: 0.0.1
#


# Set up
use strict;


# Misc vars
my (%options, $prog_version);
$prog_version = "1.0.16-pre3";


# Editable paths
$options{'installdir'} = "/usr/share/dailystrips";
$options{'docsdir'} = "/usr/share/doc/dailystrips-$prog_version";
$options{'bindir'} = "/usr/bin";


# Help overrides anything else
for (@ARGV)	{
	if (/^(--help|-h)$/) {
		print <<END_HELP;
Usage: $0 [OPTION]
This program installs dailystrips. Options are as follows:

Options:
  -q  --quiet                turns off progress messages	
      --verbose              turns on extra progress information, overrides -q
      --installdir=DIR       installs to DIR instead of /usr/share/dailystrips/

Bugs and comments to amedico\@amedico.dhs.org
END_HELP
		exit;
	}
}


# Parse options
for (@ARGV)	{
	if (/^(--installdir|-d)$/o) {
		$options{'installdir'} = $1;
	} elsif (/^(--quiet|-q)$/o) {
		$options{'quiet'} = 1;
	} elsif (/^--verbose$/o) {
		$options{'verbose'} = 1;
	} else {
		die "Unknown option: $_\n";
	}
}

# verbose overrides quiet
if ($options{'verbose'} and $options{'quiet'}) {undef $options{'quiet'}}


# Install:

# defs:
if ($options{'verbose'}) { warn "Installing definitions file to directory $options{'installdir'}\n" }

if (system("install -d -o root $options{'installdir'}")) {
	die "Error creating install directory. See above for reason.\n";
}

if (system("install -o root strips.def $options{'installdir'}/strips.def")) {
	die "Error installing definition file. See above for reason.\n";
}


# docs:
if ($options{'verbose'}) { warn "Installing docs to directory $options{'docsdir'}\n" }

if (system("install -d -o root $options{'docsdir'}")) {
	die "Error creating documentation directory. See above for reason.\n";
}

if (system("install -o root BUGS CHANGELOG CONTRIBUTORS COPYING INSTALL README README.DEFS README.LOCAL TODO $options{'docsdir'}")) {
	die "Error installing documentation files. See above for reason.\n";
}


# script:
if ($options{'verbose'}) { warn "Installing script to directory $options{'bindir'}\n" }

if (system("install -o root dailystrips.pl $options{'bindir'}")) {
	die "Error installing script. See above for reason.\n";
}


unless ($options{'quiet'}) {warn "dailystrips $prog_version installed successfully.\n" }