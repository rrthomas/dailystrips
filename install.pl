#!/usr/bin/perl -w

#
# Program Summary:
#
# Name:             install.pl
# Description:      installs dailystrips
# Author:           Andrew Medico <amedico@amedico.dhs.org>
# Created:          13 Jul 2001, 11:34 EST
# Last Modified:    02 Apr 2002, 18:59 EST
# Current Revision: 1.0.4
#


# Set up
use strict;


# Misc vars
my (%options, $prog_version);
$prog_version = "1.0.23pre1";


# Not for Win32
if ($^O =~ /Win32/ ) {
	die "install.pl is not for use on Win32 systems. Please see INSTALL file.\n";
}


# Editable paths
$options{'sharedir'} = "/usr/share/dailystrips";
$options{'docdir'} = "/usr/share/doc/dailystrips-$prog_version";
$options{'scriptdir'} = "/usr/bin";


# Help overrides anything else
for (@ARGV)	{
	if (/^(--help|-h)$/) {
		print <<END_HELP;
Usage: $0 [OPTION]
This program installs dailystrips. Options are as follows:

Options:
  -q  --quiet           turn off progress messages	
      --verbose         turn on extra progress information, overrides -q
      --sharedir=DIR    install shared files to DIR instead of
                        /usr/share/dailystrips/
      --scriptdir=DIR   install script to DIR instead of /usr/bin/
      --docdir=DIR      install documentation to DIR/dailystrips-$prog_version
                        instead of /usr/share/doc/dailystrips-$prog_version

Bugs and comments to amedico\@amedico.dhs.org
END_HELP
		exit;
	}
}


# Parse options
for (@ARGV)	{
	if (/^--sharedir=(.+)$/o) {
		$options{'sharedir'} = $1;
	} elsif (/^--scriptdir=(.+)$/o) {
		$options{'scriptdir'} = $1;
	} elsif (/^--docdir=(.+)$/o) {
		$options{'docdir'} = "$1/dailystrips-$prog_version";
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
if ($options{'verbose'}) { warn "Installing definitions file to directory $options{'sharedir'}\n" }

if (system("install -d $options{'sharedir'}")) {
	die "Error creating install directory. See above for reason.\n";
}

if (system("install strips.def $options{'sharedir'}/strips.def")) {
	die "Error installing definition file. See above for reason.\n";
}


# docs:
if ($options{'verbose'}) { warn "Installing docs to directory $options{'docdir'}\n" }

if (system("install -d $options{'docdir'}")) {
	die "Error creating documentation directory. See above for reason.\n";
}

if (system("install BUGS CHANGELOG CONTRIBUTORS COPYING INSTALL README README.DEFS README.LOCAL TODO $options{'docdir'}")) {
	die "Error installing documentation files. See above for reason.\n";
}


# script:
if ($options{'verbose'}) { warn "Installing scripts to directory $options{'scriptdir'}\n" }

if (system("install -d $options{'scriptdir'}")) {
	die "Error creating scripts directory. See above for reason.\n";
}

if (system("install dailystrips dailystrips-clean $options{'scriptdir'}")) {
	die "Error installing script. See above for reason.\n";
}


unless ($options{'quiet'}) {warn "dailystrips $prog_version installed successfully.\n" }