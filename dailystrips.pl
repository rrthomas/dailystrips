#!/usr/bin/perl -w

#
# Program Summary:
#
# Name:             dailystrips.pl
# Description:      creates an HTML page containing a number of online comics, with an easily exensible framework
# Author:           Andrew Medico <amedico@calug.net>
# Created:          23 Nov 2000, 23:33
# Last Modified:    24 Feb 2001, 03:11
# Current Revision: 1.0.9
#

# Set up
use strict;
no strict qw(refs);

use HTTP::Request;
use LWP::UserAgent;
use POSIX qw(strftime);

my (%options, $version, @localtime_today, @localtime_yesterday, $long_date, $short_date, $short_date_yesterday, @get, @strips, %defs,
    $known_strips, %groups, $known_groups, $val);

$version = "1.0.9";

$options{'defs_file'} = "strips.def";

@localtime_today = localtime;
$long_date = strftime("\%A, \%B \%-e, \%Y", @localtime_today);
$short_date = strftime("\%Y.\%m.\%d", @localtime_today);
@localtime_yesterday = localtime(time() - ( 24 * 60 * 60 ));
$short_date_yesterday = strftime("\%Y.\%m.\%d", @localtime_yesterday);

# Parse options - the must be checked first because others depend on their values
for (@ARGV)	{
	if ($_ =~ m/^--basedir=(.*)$/o) {
		unless (chdir $1) { die "Error: could not change directory to $1\n" }
	}
	if ($_ =~ m/^--defs=(.*)$/o) {
		$options{'defs_file'} = $1;
	}
}

#get strip definitions (do it now because info is used below)
&get_defs;
$known_strips = join('|', sort keys %defs);
$known_groups = join('|', sort keys %groups);

for (@ARGV)	{
	if ($_ eq "" or $_ =~ m/^(--help|-h)$/o) {
		print "Usage: $0 [OPTION] STRIPS\n";
		print "'all' may be used to retrieve all known strips,\n";
		print "or use option --list to list available strips\n";
		print "\nOptions:\n";
		print "  -q  --quiet            turns off progress messages\n";		
		print "      --output=FILE      outputs HTML to FILE instead of STDOUT\n";
		print "                         (does not apply to local mode\n";
		print "  -l  --local            outputs HTML to file and saves strips locally\n";
		print "      --noindex          disables symlinking current page to index.html\n";
		print "                         (local mode only)\n";
		print "  -a  --archive          generates archive.html as a list of all days,\n";
		print "                         (local mode only)\n";
		print "  -d  --dailydir         creates a separate directory for each day's files\n";
		print "                         (local mode only)\n";
		print "  -s  --save             if it appears that a particular strip has been\n";
		print "                         downloaded, does not attempt to re-download it\n";
		print "                         (local mode only)\n";
		print "  -n  --new              if today's file and yesterday's file for a strip are the\n";
		print "                         same, does not symlink to save space\n";
		print "                         (local mode only, required on non-*NIX platforms\n";
		print "      --defs=FILE        use alternate strips definition file\n";
		print "      --basedir=DIR      work in specified directory instead of current directory\n";
		print "                         (program will look here for strip definitions, previous\n";
		print "                         HTML files, etc. and save new files here)\n";
		print "      --list             list available strips\n";
		print "      --proxy=host:port  Uses specified HTTP proxy server (overrides environment\n";
		print "                         proxy,if set)\n";
		print "      --noenvproxy       Ignores the http_proxy environment variable, if set\n";
		print "  -v  --version          Prints version number\n";
		print "\nBugs and comments to amedico\@calug.net\n";
		exit;
	} elsif ($_ =~ m/^--list$/o) {
format =
@<<<<<<<<<<<<<<<<<<<< 	@<<<<<<<<<<<<<<<<<<<<<<<<<<
$_, $val
.
		print "Available strips:\n";
		for (split(/\|/, $known_strips)) {
			$val = $defs{$_}{'name'};
			write;
		}
		
		print "\nAvailable groups:\n";
		for (split(/\|/, $known_groups)) {
			$val = $groups{$_}{'desc'};
			write;
		}
		exit;
	} elsif ($_ =~ m/^(--archive|-a)$/o) {
		$options{'make_archive'} = 1;
	} elsif ($_ =~ m/^(--dailydir|-d)$/o) {
		$options{'dailydir'} = 1;
	} elsif ($_ =~ m/^(--quiet|-q)$/o) {
		$options{'quiet'} = 1;
	} elsif ($_ =~ m/^(--save|-s)$/o) {
		$options{'save_existing'} = 1;
	} elsif ($_ =~ m/^--output=(.*)$/o) {
		$options{'output_file'} = $1;
	} elsif ($_ =~ m/^(--new|-n)$/o) {
		$options{'new'} = 1;
	} elsif ($_ =~ m/^(--version|-v)$/o) {
		print "dailystrips version $version\n";
		exit;
	} elsif ($_ =~ m/^--defs=(.*)$/o or $_ =~ m/^--basedir=(.*)$/o) {
		# nothing done here - just prevent an "unknown option" error (all the more reason to switch to Getopts)
	} elsif ($_ =~ m/^($known_strips|all)$/io) {
		if ($_ eq "all") {
			push (@get, split(/\|/, $known_strips));
		} else {
			push(@get, $_);
		}
	} elsif ($_ =~ m/^@($known_groups)$/io) {
		push(@get, split(/;/, $groups{$1}{'strips'}));
	} elsif ($_ =~ m/^(--local|-l)$/o) {
		$options{'local_mode'} = 1;
	} elsif ($_ =~ m/^--noindex$/o) {
		$options{'no_index'} = 1;
	} elsif ($_ =~ m/^--noenvproxy$/o) {
		$options{'no_env_proxy'} = 1;
	} elsif ($_ =~ m/^--proxy=/o) {
		unless ($_ =~ m/^--proxy=((.*?):(.*?))$/o) {die "Invalid proxy server\n"}
		$options{'http_proxy'} = $1;
	} else {
		die "Unknown option: $_\n";
	}
}

# Un-needed vars
undef $known_strips; undef $known_groups; undef $val;

unless (@get) {
	die "Error: no strip specified (--list to list available strips)\n";
}

#Set proxy
if (!defined $options{'no_env_proxy'} && !defined $options{'http_proxy'} ) {
	if (defined $ENV{'http_proxy'} ) {
		my $env_proxy = $ENV{'http_proxy'};
		$options{'http_proxy'} = $env_proxy;
	}
}
if (defined $options{'http_proxy'}) {
	unless ($options{'http_proxy'} =~ m/^http:\/\//io) {$options{'http_proxy'} = "http://" . $options{'http_proxy'}}
}

if (defined $options{'local_mode'}) {
	unless (defined $options{'quiet'}) { print STDERR "Operating in local mode\n" }
	
	if (defined $options{'dailydir'}) {
		unless (defined $options{'quiet'}) { print STDERR "Operating in daily directory mode\n" }
		
		unless (-d $short_date) {
			mkdir ($short_date, 0755) or die "Error: could not create today's directory ($short_date/)\n"
		}
		
		open(STDOUT, ">$short_date/dailystrips-$short_date.html") or die "Error: could not open HTML file ($short_date/dailystrips-$short_date.html) for writing\n";
		
		system("rm -f dailystrips-$short_date.html;ln -s $short_date/dailystrips-$short_date.html dailystrips-$short_date.html");
	} else {
		open(STDOUT, ">dailystrips-$short_date.html") or die "Error: could not open HTML file (dailystrips-$short_date.html) for writing\n";
    }

    unless (defined $options{'no_index'}) { system("rm -f index.html;ln -s dailystrips-$short_date.html index.html") }

	if (defined $options{'make_archive'}) {
	
		unless (-e "archive.html") { die "Error: archive.html not found" }
		open(ARCHIVE, "<archive.html") or die "Error: could not open archive.html for reading\n";
		my @archive = <ARCHIVE>;
		close(ARCHIVE);

		unless (grep(/<a href="dailystrips-$short_date.html">/, @archive)) {
			for (@archive) {
				if ($_ =~ s/(<!--insert below-->)/$1\n<a href="dailystrips-$short_date.html">$long_date<\/a><br>/) {
					open(ARCHIVE, ">archive.html") or die "Error: could open archive.html for writing\n";
					print ARCHIVE @archive;
					close(ARCHIVE);
					last;
				}
			}
		}
	}
	
	# Update previous day's file with a "Next Day" link to today's file
	if (open(PREVIOUS, "<dailystrips-$short_date_yesterday.html")) {
		my @previous_page = <PREVIOUS>;
		close(PREVIOUS);
	
		# Don't bother if no tag exists in the file (because it has already been updated)
		if (grep(/<!--nextday-->/, @previous_page)) {
			my $match_count;
		
			for (@previous_page) {
				if ($_ =~ s/<!--nextday-->/ | <a href="dailystrips-$short_date.html">Next day<\/a>/) {
					$match_count++;
					last if ($match_count == 2);
				}
			}
		
			if (open(PREVIOUS, ">dailystrips-$short_date_yesterday.html")) {
				print PREVIOUS @previous_page;
				close(PREVIOUS);
			} else {
				 warn "Warning: could open dailystrips-$short_date_yesterday.html for writing\n";
			}
		} else {
			warn "Warning: did not find any tag in previous day's file to make today's link\n";
		}
	} else {
		warn "Warning: could not open dailystrips-$short_date_yesterday.html for reading\n";
	}


} elsif (defined $options{'output_file'}) {
	unless (defined $options{'quiet'}) { print STDERR "Writing to file $options{'output_file'}\n" }
	open(STDOUT, ">$options{'output_file'}") or die "Could not open output file ($options{'output_file'}) for writing\n";
}


# Download image URLs
unless (defined $options{'quiet'}) { print STDERR "Retrieving URLS..." }
for (@get) {
	&get_strip($_);
}
#undef @get;
unless (defined $options{'quiet'}) { print STDERR "done\n" }


# Generate HTML page
print <<END_HEADER;
<html>

<head>
	<title>dailystrips for $long_date</title>
</head>

<body bgcolor=\"#ffffff\" text=\"#000000\" link=\"#ff00ff\">

<center>
	<font face=\"helvetica\" size=\"+2\"><b><u>dailystrips for $long_date</u></b></font>
</center>

<p><font face=\"helvetica\">< <a href=\"dailystrips-$short_date_yesterday.html\">Previous day</a><!--nextday--> ></font></p>

<table border=\"0\">
END_HEADER

#"#kwrite's syntax higlighting is buggy..

if ((defined $options{'local_mode'}) and (not defined $options{'quiet'})) { print STDERR "Saving strips locally..." }

for (@strips) {
	my ($strip, $homepage, $img_addr, $updated, $referer) = split(/;/, $_);
	my ($img_line, $local_name, $image, $ext);
	my ($local_name_yesterday);
	
	if ($img_addr =~ "^unavail") {
		$img_line = "[Error - unable to retrieve URL]";
	} else {
		if (defined $options{'local_mode'}) {
			# local mode - download strips
			$img_addr =~ m/http:\/\/(.*)\/(.*)\.(.*)$/o;
			if (defined $3) { $ext = ".$3" } else { $ext = ""}
			
			if (defined $options{'dailydir'}) {
				$local_name_yesterday = "$short_date_yesterday/$strip-$short_date_yesterday$ext";
				$local_name = "$short_date/$strip-$short_date$ext";
			} else {
				$local_name_yesterday = "$strip-$short_date_yesterday$ext";				
				$local_name = "$strip-$short_date$ext";
			}
			
			if (defined $options{'save_existing'} and  -e $local_name) {
				# strip already exists - skip download
				$img_addr = $local_name;
				$img_addr =~ s/ /\%20/go;
				$img_line = "<img src=\"$img_addr\" alt=\"$strip\">";
			} else {
				# need to download
				$image = &http_get($img_addr,$referer);
				if ($image =~ m/^ERROR/o) {
					$img_line = "[Error - unable to download image]";
				} else {
					if (-l $local_name) {unlink $local_name} # in case today's file is a symlink to yesterday's
					
					open(IMAGE, ">$local_name");
					print IMAGE $image;
					close(IMAGE);
					
					# Check to see if this is the same file as yesterday
					if (system("diff \"$local_name_yesterday\" \"$local_name\" >/dev/null 2>&1") == 0) {
						
						if ($updated eq "daily") {
							#don't save the same strip as yesterday if it's supposed to be updated daily
							system("rm -f \"$local_name\"");
							$img_line = "[Error - new strip not available]";
						} else {
							#semidaily strips are allowed to be duplicates
							unless ($options{'new'}) {
								if (system("diff \"$local_name_yesterday\" \"$local_name\" >/dev/null 2>&1") == 0) {
									system("rm -f \"$local_name\"");
									system("ln -s \"../$local_name_yesterday\" \"$local_name\" >/dev/null 2>&1");
								}
							}
							
							$img_addr = $local_name;
							$img_addr =~ s/ /\%20/go;
							$img_line = "<img src=\"$img_addr\" alt=\"$strip\">";
						}
					} else {
						#strip is new for today
						$img_addr = $local_name;
						$img_addr =~ s/ /\%20/go;
						$img_line = "<img src=\"$img_addr\" alt=\"$strip\">";
					}
					
				}
			}
		} else {
			# regular mode - just give addresses to strips on their webserver
			$img_line = "<img src=\"$img_addr\" alt=\"$strip\">";
		}
	}
		
	print <<END_STRIP;
	<tr>
		<td>
			<font face=\"helvetica\" size=\"+1\"><b><a href=\"$homepage\">$strip</a></b></font>
		</td>
	</tr>
	<tr>
		<td>
			$img_line
			<p>&nbsp;</p>
		</td>
	</tr>
END_STRIP
}
#"#kwrite's syntax highlighting is buggy..


if ((defined $options{'local_mode'}) and (not defined $options{'quiet'})) { print STDERR "done\n" }

print <<END_FOOTER;
</table>

<p><font face=\"helvetica\">< <a href=\"dailystrips-$short_date_yesterday.html\">Previous day</a><!--nextday--> ></font></p>

<font face=\"helvetica\">Generated by dailystrips $version, by <a href=\"mailto:amedico\@calug.net\">Andrew Medico</a></font>

</body>

</html>
END_FOOTER

#"// # kwrite's syntax highlighting is a bit off.. this fixes things

sub http_get {
	my ($url, $referer) = @_;
	my $headers;
	
	if (defined $referer) {
		$headers = new HTTP::Headers;
		$headers->referer($referer);
	}
	
	my $request = HTTP::Request->new('GET', $url, $headers);
	my $ua = LWP::UserAgent->new;
	$ua->agent("dailystrips $version: " . $ua->agent());
	
	# could do without 'if defined..' if not running under -w -- maybe
	if (defined $options{'http_proxy'}) { $ua->proxy('http', $options{'http_proxy'}) }
	
	my $response = $ua->request($request);
	(my $status = $response->status_line()) =~ s/^(\d+)/$1:/;

	if ($response->is_error()) {
		return "ERROR: $status";
	} else {
		return $response->content;
	}
}

sub get_strip {
	my ($strip) = @_;
	my ($page, $addr);
	
	if ($defs{$strip}{'type'} eq "search") {
		$page = &http_get($defs{$strip}{'searchpage'});

		if ($page =~ m/^ERROR/) {
			$addr = "unavail-server";
		} else {
			$page =~ m/$defs{$strip}{'searchpattern'}/i;
			
			unless (defined ${$defs{$strip}{'matchpart'}}) {
				$addr = "unavail-nomatch";
			} else {
				$addr = $defs{$strip}{'baseurl'} . "${$defs{$strip}{'matchpart'}}";
			}
		}
		
	} elsif ($defs{$strip}{'type'} eq "generate") {
		$addr = $defs{$strip}{'imageurl'};
		# could do without 'if defined..' if not running under -w
		if (defined $defs{$strip}{'baseurl'}) { $addr = $defs{$strip}{'baseurl'} . $addr }
	}
	
	unless ($addr =~ m/^http:\/\//io || $addr =~ m/^unavail/io) { $addr = "http://" . $addr }
	
	push(@strips,"$defs{$strip}{'name'};$defs{$strip}{'homepage'};$addr;$defs{$strip}{'updated'};$defs{$strip}{'referer'}")
}

sub get_defs {
	my ($strip, $class, $sectype, %classes, $group);
	my $line = 1;
	
	open(DEFS, "<$options{'defs_file'}") or die "Error: could not open strip definitions file\n";
	my @defs_file = <DEFS>;
	close(DEFS);
	
	@defs_file = grep(!/^\s*#/, @defs_file);		# weed out comment-only lines
	@defs_file = grep(!/^\s*\n/, @defs_file);		# get rid of blank lines
	
	for (@defs_file) {
		chomp $_;
		$_ =~ s/^\s+//o; $_ =~ s/\s+$//o; $_ =~ s/#(.*)//o;

		if (not defined $sectype) {
			if ($_ =~ m/^strip\s+(\w+)$/io)
			{
				$strip = $1;
				$sectype = "strip";
			}
			elsif ($_ =~ m/^class\s+(.*)$/io)
			{
				$class = $1;
				$sectype = "class";
			}
			elsif ($_ =~ m/^group\s+(.*)$/io)
			{
				$group = $1;
				$sectype = "group";
			}
			elsif ($_ =~ m/^(.*)/io)
			{
				die "Unknown keyword '$1' at $options{'defs_file'} line $line\n";
			}
		}
		elsif ($_ =~ m/^end$/io)
		{
			if ($sectype eq "class")
			{
				undef $class
			}		
			elsif ($sectype eq "strip")
			{
				if (defined $defs{$strip}{'useclass'}) {
					my $using_class = $defs{$strip}{'useclass'};
					
					for (qw(homepage searchpage searchpattern baseurl imageurl referer)) {
						if (defined $classes{$using_class}{$_} and not defined $defs{$strip}{$_}) {
							my $classvar = $classes{$using_class}{$_};
							$classvar =~ s/(\$[0-9])/$defs{$strip}{$1}/g;
							$classvar =~ s/\$strip/$strip/g;
							$defs{$strip}{$_} = $classvar;
						}
					}
				
					for (qw(type matchpart updated)) {
						if (defined $classes{$using_class}{$_} and not defined $defs{$strip}{$_}) {
							$defs{$strip}{$_} = $classes{$using_class}{$_};
						}
					}	
				}	
						
				#substitute auto vars for real vals here/set defaults
				unless (defined $defs{$strip}{'updated'})    {$defs{$strip}{'updated'} = "daily"}
				unless (defined $defs{$strip}{'searchpage'}) {$defs{$strip}{'searchpage'} = $defs{$strip}{'homepage'}}
				unless (defined $defs{$strip}{'referer'})    {
					if (defined $defs{$strip}{'searchpage'}) {
						$defs{$strip}{'referer'} = $defs{$strip}{'searchpage'}
					} else {
						$defs{$strip}{'referer'} = $defs{$strip}{'homepage'}
					}
				}
				
				for (qw(homepage searchpage searchpattern imageurl baseurl referer)) {
					#other vars in definition
					# could do without 'if defined..' if not running under -w
					if (defined $defs{$strip}{$_}) {$defs{$strip}{$_} =~ s/\$(homepage|searchpage|searchpattern|imageurl|baseurl|referer)/$defs{$strip}{$1}/g}
				}			
				
				for (qw(homepage searchpage searchpattern imageurl baseurl referer)) {
					#dates
					# could do without 'if defined..' if not running under -w
					if (defined $defs{$strip}{$_}) { $defs{$strip}{$_} =~ s/(\%(-?)[a-zA-Z])/strftime("$1", @localtime_today)/ge }
				}
				
				
				#sanity check vars
				for (qw(name homepage type)) {
					unless (defined $defs{$strip}{$_})     { die "Error: strip $strip has no '$_' value\n" }
				}
				
				for (qw(homepage searchpage baseurl imageurl)){	
					if (defined $defs{$strip}{$_}) {
						unless ($defs{$strip}{$_} =~ m/^http:\/\//io) { die "Error: strip $strip has invalid $_\n" }
					}
				}
				
				if ($defs{$strip}{'type'} eq "search") {
					unless (defined $defs{$strip}{'searchpattern'}) { die "Error: strip $strip has no 'searchpattern' value\n" }
					unless (defined $defs{$strip}{'matchpart'})     { die "Error: strip $strip has no 'matchpart' value\n" }
				} else {
					unless (defined $defs{$strip}{'imageurl'})      { die "Error: strip $strip has no 'imageurl' value\n" }
				}
				
				#foreach my $strip (keys %defs) {
				#	foreach my $key (qw(homepage searchpage searchpattern imageurl baseurl referer)) {
				#		print STDERR "DEBUG: $strip:$key=$defs{$strip}{$key}\n";
				#	}
				#	print STDERR "DEBUG: $strip:name=$defs{$strip}{'name'}\n";
				#}
			
				undef $strip;
			}
			elsif ($sectype eq "group")
			{
				chop $groups{$group}{'strips'};
				
				unless (defined $groups{$group}{'desc'}) { $groups{$group}{'desc'} = "[No description]"}
				
				undef $group;
			}
			
			undef $sectype;
		}
		elsif ($sectype eq "class") {
			if ($_ =~ m/^homepage\s+(.+)$/io) {
				my $val = $1;
				$classes{$class}{'homepage'} = $val;
			}
			elsif ($_ =~ m/^type\s+(.+)$/io)
			{
				my $val = $1;
				unless ($val =~ m/^(search|generate)$/io) { die "Error: invalid types at $options{'defs_file'} line $line\n" }
				$classes{$class}{'type'} = $val;
			}
			elsif ($_ =~ m/^searchpage\s+(.+)$/io)
			{
				my $val = $1;
				$classes{$class}{'searchpage'} = $val;
			}
			elsif ($_ =~ m/^searchpattern\s+(.+)$/io)
			{
				$classes{$class}{'searchpattern'} = $1;
			}
			elsif ($_ =~ m/^matchpart\s+(.+)$/o)
			{
				my $val = $1;
				unless ($val =~ m/^\d+$/io) { die "Error: invalid matchpart at $options{'defs_file'} line $line\n" }
				$classes{$class}{'matchpart'} = $val;
			}
			elsif ($_ =~ m/^baseurl\s+(.+)$/io)
			{
				my $val = $1;
				$classes{$class}{'baseurl'} = $val;
			}
			elsif ($_ =~ m/^imageurl\s+(.+)$/io)
			{
				my $val = $1;
				$classes{$class}{'imageurl'} = $val;
			}
			elsif ($_ =~ m/^referer\s+(.+)$/io)
			{
				$classes{$class}{'referer'} = $1;
			}
			elsif ($_ =~ m/^updated\s+(.+)$/io)
			{
				$classes{$class}{'updated'} = $1;
			}
			elsif ($_ =~ m/^(.+)(\s+?)/io)
			{
				die "Unknown keyword '$1' at $options{'defs_file'} line $line\n";
			}
		}
		elsif ($sectype eq "strip") {
			if ($_ =~ m/^name\s+(.+)$/io)
			{
				$defs{$strip}{'name'} = $1;
			}
			elsif ($_ =~ m/^useclass\s+(.+)$/io)
			{
				$defs{$strip}{'useclass'} = $1;
			}
			elsif ($_ =~ m/^homepage\s+(.+)$/io) {
				my $val = $1;
				$defs{$strip}{'homepage'} = $val;
			}
			elsif ($_ =~ m/^type\s+(.+)$/io)
			{
				my $val = $1;
				unless ($val =~ m/^(search|generate)$/io) { die "Error: invalid type at $options{'defs_file'} line $line\n" }
				$defs{$strip}{'type'} = $val;
			}
			elsif ($_ =~ m/^searchpage\s+(.+)$/io)
			{
				my $val = $1;
				$defs{$strip}{'searchpage'} = $val;
			}
			elsif ($_ =~ m/^searchpattern\s+(.+)$/io)
			{
				$defs{$strip}{'searchpattern'} = $1;
			}
			elsif ($_ =~ m/^matchpart\s+(.+)$/o)
			{
				my $val = $1;
				unless ($val =~ m/^\d+$/io) { die "Error: invalid matchpart at $options{'defs_file'} line $line\n" }
				$defs{$strip}{'matchpart'} = $val;
			}
			elsif ($_ =~ m/^baseurl\s+(.+)$/io)
			{
				my $val = $1;
				$defs{$strip}{'baseurl'} = $val;
			}
			elsif ($_ =~ m/^imageurl\s+(.+)$/io)
			{
				my $val = $1;
				$defs{$strip}{'imageurl'} = $val;
			}
			elsif ($_ =~ m/^updated\s+(.+)$/io)
			{
				$defs{$strip}{'updated'} = $1;
			}
			elsif ($_ =~ m/^referer\s+(.+)$/io)
			{
				$defs{$strip}{'referer'} = $1;
			}
			elsif ($_ =~ m/^(\$[0-9])\s+(.+)$/io)
			{
				$defs{$strip}{$1} = $2;
			}
			elsif ($_ =~ m/^(.+)(\s+?)/io)
			{
				die "Unknown keyword '$1' at $options{'defs_file'} line $line, in strip $strip\n";
			}
		} elsif ($sectype eq "group") {
			if ($_ =~ m/^desc\s+(.+)$/io)
			{
				$groups{$group}{'desc'} = $1;
			}
			elsif ($_ =~ m/^include\s+(.+)$/io)
			{
				$groups{$group}{'strips'} .= join(';', split(/\s+/, $1)) . ";";
			}
			elsif ($_ =~ m/^(.+)(\s+?)/io)
			{
				die "Unknown keyword '$1' at $options{'defs_file'} line $line, in group $group\n";
			}
		}
			
		
		
		$line++;
	}
	
	# Post-processing validation
	for $group (keys %groups) {
		for ( split(/;/, $groups{$group}{'strips'}) ) {
			unless (defined $defs{$_}) {
				die "Error: group $group includes non-existant strip $_\n";
			}
		}
	}
	
}