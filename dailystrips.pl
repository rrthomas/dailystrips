#!/usr/bin/perl

#
# Program Summary:
#
# Name:             dailystrips.pl
# Description:      creates an HTML page containing a number of online comics, with an easily exensible framework
# Author:           Andrew Medico <amedico@calug.net>
# Created:          23 Nov 2000, 23:33
# Last Modified:    11 Mar 2001, 14:04
# Current Revision: 1.0.12
#

# Set up
use strict;
no strict qw(refs);

use HTTP::Request;
use LWP::UserAgent;
use POSIX qw(strftime);

my (%options, $version, $time_today, @localtime_today, @localtime_yesterday, @localtime_tomorrow, $long_date, $short_date,
    $short_date_yesterday, $short_date_tomorrow, @get, @strips, %defs,$known_strips, %groups, $known_groups, $val, $link_tomorrow,
    $no_dateparse);

unless (eval "use Date::Parse") {
	print STDERR "Warning: Date::Parse not installed. --date option can not be used\n";
	$no_dateparse = 1;
}

$version = "1.0.12";

$options{'defs_file'} = "strips.def";

$time_today = time;

# Parse options - the must be checked first because others depend on their values
for (@ARGV)	{
	if (/^--basedir=(.*)$/o) {
		unless (chdir $1) { die "Error: could not change directory to $1\n" }
	}
	if (/^--defs=(.*)$/o) {
		$options{'defs_file'} = $1;
	}
	
	if ($_=~ m/^--date=(.*)$/o) {
		if ($no_dateparse) {die "Error: cannot use --date - Date::Parse not installed\n"}
		unless ($time_today = str2time $1) {die "Error: invalid date specified\n"}
	}
}


# setup time variables...
@localtime_today = localtime $time_today;
$long_date = strftime("\%A, \%B \%-e, \%Y", @localtime_today);
$short_date = strftime("\%Y.\%m.\%d", @localtime_today);
@localtime_yesterday = localtime($time_today - ( 24 * 60 * 60 ));
$short_date_yesterday = strftime("\%Y.\%m.\%d", @localtime_yesterday);
@localtime_tomorrow = localtime ($time_today + 24 * 60 * 60);
$short_date_tomorrow = strftime("\%Y.\%m.\%d", @localtime_tomorrow);

#get strip definitions (do it now because info is used below)
&get_defs;
$known_strips = join('|', sort keys %defs);
$known_groups = join('|', sort keys %groups);

for (@ARGV)	{
	if ($_ eq "" or /^(--help|-h)$/o) {
		print <<END_HELP;
Usage: $0 [OPTION] STRIPS
STRIPS can be a mix of strip names and group names
(group names must be predeeded by an '\@' symbol)
'all' may be used to retrieve all known strips,
or use option --list to list available strips

Options:
  -q  --quiet                turns off progress messages		
      --verbose              turns on extra progress information, overrides -q
      --output=FILE          outputs HTML to FILE instead of STDOUT
                             (does not apply to local mode)
  -l  --local                outputs HTML to file and saves strips locally
      --noindex              disables symlinking current page to index.html
                             (local mode only)
  -a  --archive              generates archive.html as a list of all days,
                             (local mode only)
  -d  --dailydir             creates a separate directory for each day's files
                             (local mode only)
      --stripdir             creates a separate directory for each strip's files
                             (local mode only)
  -s  --save                 if it appears that a particular strip has been
                             downloaded, does not attempt to re-download it
                             (local mode only)
      --date=DATE            Use value DATE instead of local time
                             (DATE is parsed by Date::Parse function
  -n  --new                  if today's file and yesterday's file for a strip
                             are the same, does not symlink to save space
                             (local mode only, required on non-*NIX platforms
      --defs=FILE            use alternate strips definition file
      --basedir=DIR          work in specified directory instead of current directory
                             (program will look here for strip definitions, previous
                             HTML files, etc. and save new files here)
      --list                 list available strips
      --proxy=host:port      Uses specified HTTP proxy server (overrides environment
                             proxy, if set)
      --proxyauth=user:pass  Sets username and password for proxy server
      --noenvproxy           Ignores the http_proxy environment variable, if set
      --nospaces             Removes spaces from image filenames (local mode only)
  -v  --version              Prints version number

Bugs and comments to amedico\@calug.net
END_HELP
		exit;
	} elsif (/^--list$/o) {
format =
@<<<<<<<<<<<<<<<<<<<<<<<< 	@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
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
	} elsif (/^(--archive|-a)$/o) {
		$options{'make_archive'} = 1;
	} elsif (/^(--dailydir|-d)$/o) {
		if (defined $options{'stripdir'}) {die "Error: --dailydir and --stripdir cannot be used together\n"}
		$options{'dailydir'} = 1;
	} elsif (/^(--quiet|-q)$/o) {
		$options{'quiet'} = 1;
	} elsif (/^--verbose$/o) {
		$options{'verbose'} = 1;
	} elsif (/^(--save|-s)$/o) {
		$options{'save_existing'} = 1;
	} elsif ($_ =~ m/^--stripdir$/o) {
		if (defined $options{'dailydir'}) {die "Error: --dailydir and --stripdir cannot be used together\n"}
		$options{'stripdir'} = 1;
	} elsif (/^--output=(.*)$/o) {
		$options{'output_file'} = $1;
	} elsif (/^(--new|-n)$/o) {
		$options{'new'} = 1;
	} elsif (/^(--nospaces)$/o) {
		$options{'nospaces'} = 1;
	} elsif (/^(--version|-v)$/o) {
		print "dailystrips version $version\n";
		exit;
	} elsif ($_ =~ m/^--defs=(.*)$/o or $_ =~ m/^--basedir=(.*)$/o or $_ =~ m/^--date=.*$/o) {
		# nothing done here - just prevent an "unknown option" error (all the more reason to switch to Getopts)
	} elsif (/^($known_strips|all)$/io) {
		if ($_ eq "all") {
			push (@get, split(/\|/, $known_strips));
		} else {
			push(@get, $_);
		}
	} elsif (/^@($known_groups)$/io) {
		push(@get, split(/;/, $groups{$1}{'strips'}));
	} elsif (/^(--local|-l)$/o) {
		$options{'local_mode'} = 1;
	} elsif (/^--noindex$/o) {
		$options{'no_index'} = 1;
	} elsif (/^--noenvproxy$/o) {
		$options{'no_env_proxy'} = 1;
	} elsif (/^--proxyauth/o) {
		unless (/^--proxyauth=((.*?):(.*?))$/o) {die "Error: incorrectly formatted proxy username/password\n"}
		$options{'http_proxy_auth'} = $1;
	} elsif (/^--proxy/o) {
		unless (/^--proxy=((.*?):(.*?))$/o) {die "Error: incorrectly formatted proxy server\n"}
		$options{'http_proxy'} = $1;
	} else {
		die "Unknown option: $_\n";
	}
}

# verbose overrides quiet
if ($options{'verbose'} and $options{'quiet'}) {undef $options{'quiet'}}

# Un-needed vars
undef $known_strips; undef $known_groups; undef $val;

unless ($options{'quiet'}) {print STDERR "dailystrips $version starting:\n"}

unless (@get) {
	die "Error: no strip specified (--list to list available strips)\n";
}

#Set proxy
if (!defined $options{'no_env_proxy'} and !defined $options{'http_proxy'} and defined $ENV{'http_proxy'} ) {
	unless ($ENV{'http_proxy'} =~ m/^(.*?):(.*?)$/o) {die "Error: incorrectly formatted proxy server environment variable\n"}
	$options{'http_proxy'} = $ENV{'http_proxy'};
}
if ($options{'http_proxy'}) {
	unless ($options{'http_proxy'} =~ m/^http:\/\//io) {$options{'http_proxy'} = "http://" . $options{'http_proxy'}}
	if ($options{'verbose'}) { print STDERR "Using proxy server $options{'http_proxy'}\n" }
	if ($options{'verbose'} and $options{'http_proxy_auth'}) { print STDERR "Using proxy server authentication\n" }
}

if ($options{'local_mode'}) {
	unless ($options{'quiet'}) { print STDERR "Operating in local mode\n" }
	
	if (defined $options{'dailydir'}) {
		unless ($options{'quiet'}) { print STDERR "Operating in daily directory mode\n" }
		
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
				if (s/(<!--insert below-->)/$1\n<a href="dailystrips-$short_date.html">$long_date<\/a><br>/) {
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
				if (s/<!--nextday-->/ | <a href="dailystrips-$short_date.html">Next day<\/a>/) {
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
	unless ($options{'quiet'}) { print STDERR "Writing to file $options{'output_file'}\n" }
	open(STDOUT, ">$options{'output_file'}") or die "Could not open output file ($options{'output_file'}) for writing\n";
}


# Download image URLs
unless ($options{'quiet'}) {
	if ($options{'verbose'}) {
		print STDERR "\nRetrieving URLS:\n"
	} else {
		print STDERR "\nRetrieving URLS..."
	}
}
for (@get) {
	if ($options{'verbose'}) { print STDERR "Retrieving URL for $_\n" }
	&get_strip($_);
}
unless ($options{'quiet'}) {
	if ($options{'verbose'}) {
		print STDERR "\nRetrieving URLS: done\n"
	} else {
		print STDERR "done\n"
	}
}

if (-e "dailystrips-$short_date_tomorrow.html") {
	$link_tomorrow = " | <a href=\"dailystrips-$short_date_tomorrow.html\">Next day</a>"
} else {
	$link_tomorrow = "<!--nextday-->"
}

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

<p><font face=\"helvetica\">
&lt; <a href=\"dailystrips-$short_date_yesterday.html\">Previous day</a>$link_tomorrow &gt;
</font></p>

<table border=\"0\">
END_HEADER

#"#kwrite's syntax higlighting is buggy..

if ($options{'local_mode'} and !$options{'quiet'}) {
	if ($options{'verbose'}) {
		print STDERR "\nDownloading strip files:\n"
	} else {
		print STDERR "Downloading strip files..."
	}
}
#if ($options{'local_mode'} and !$options{'quiet'}) { print STDERR "\nDownloading strip files:\n" }

for (@strips) {
	my ($strip, $name, $homepage, $img_addr, $updated, $referer) = split(/;/, $_);
	my ($img_line, $local_name, $image, $ext);
	my ($local_name_yesterday);
	
	if ($options{'verbose'} and $options{'local_mode'}) { print STDERR "Downloading strip file for " . lc((split(/;/, $_))[0]) . "\n" }
	
	if ($img_addr =~ "^unavail") {
		if ($options{'verbose'}) { print STDERR "Error: $strip: could not retrieve URL\n" }
		$img_line = "[Error - unable to retrieve URL]";
	} else {
		if ($options{'local_mode'}) {
			# local mode - download strips
			$img_addr =~ m/http:\/\/(.*)\/(.*)\.(.*)$/o;
			if (defined $3) { $ext = ".$3" }
			
			if ($options{'stripdir'}) {
 				$local_name_yesterday = "$name/$short_date_yesterday$ext";
 				$local_name = "$name/$short_date$ext";
 				unless ( -d $strip) { mkdir $name, 0755; }
 			} elsif ($options{'dailydir'}) {
				$local_name_yesterday = "$short_date_yesterday/$name-$short_date_yesterday$ext";
				$local_name = "$short_date/$name-$short_date$ext";
			} else {
				$local_name_yesterday = "$name-$short_date_yesterday$ext";				
				$local_name = "$name-$short_date$ext";
			}
			
			if ($options{'nospaces'}) {
				# impossible to tell for sure if previous day's file
				# used --nospaces or not, but this should work more
				# often
				$local_name_yesterday =~ s/(\ )//g;
				$local_name =~ s/(\ )//g;
			}

			if ($options{'save_existing'} and  -e $local_name) {
				# strip already exists - skip download
				$img_addr = $local_name;
				$img_addr =~ s/ /\%20/go;
				$img_line = "<img src=\"$img_addr\" alt=\"$name\">";
			} else {
				# need to download
				$image = &http_get($img_addr,$referer);
				if ($image =~ m/^ERROR/o) {
					if ($options{'verbose'}) { print STDERR "Error: $strip: could not download strip\n" }
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
							$img_line = "<img src=\"$img_addr\" alt=\"$name\">";
						}
					} else {
						#strip is new for today
						$img_addr = $local_name;
						$img_addr =~ s/ /\%20/go;
						$img_line = "<img src=\"$img_addr\" alt=\"$name\">";
					}
					
				}
			}
		} else {
			# regular mode - just give addresses to strips on their webserver
			$img_line = "<img src=\"$img_addr\" alt=\"$name\">";
		}
	}
		
	print <<END_STRIP;
	<tr>
		<td>
			<font face=\"helvetica\" size=\"+1\"><b><a href=\"$homepage\">$name</a></b></font>
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
if ($options{'local_mode'} and !$options{'quiet'}) {
	if ($options{'verbose'}) {
		print STDERR "\nDownloading strip files: done\n"
	} else {
		print STDERR "done\n"
	}
}

print <<END_FOOTER;
</table>

<p><font face=\"helvetica\">
&lt; <a href=\"dailystrips-$short_date_yesterday.html\">Previous day</a>$link_tomorrow &gt;
</font></p>

<font face=\"helvetica\">Generated by dailystrips $version</font>

</body>

</html>
END_FOOTER

#"// # kwrite's syntax highlighting is a bit off.. this fixes things

sub http_get {
	my ($url, $referer) = @_;

	my $headers = new HTTP::Headers;;
	my $request = HTTP::Request->new('GET', $url, $headers);
	my $ua = LWP::UserAgent->new;
	$ua->agent("dailystrips $version: " . $ua->agent());
	$ua->proxy('http', $options{'http_proxy'});
	$headers->authorization_basic(split(/:/, $options{'http_proxy_auth'}));
	$headers->referer($referer);
				
	my $response = $ua->request($request);
	(my $status = $response->status_line()) =~ s/^(\d+)/$1:/;

	if ($response->is_error()) {
		if ($options{'verbose'}) { print STDERR "Error: could not download $url: $status\n" }
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
			if ($options{'verbose'}) { print STDERR "Error: $strip: could not download searchpage $defs{$strip}{'searchpage'}\n" }
			$addr = "unavail-server";
		} else {
			$page =~ m/$defs{$strip}{'searchpattern'}/i;
			
			unless (${$defs{$strip}{'matchpart'}}) {
				if ($options{'verbose'}) { print STDERR "Error: $strip: searchpattern $defs{$strip}{'searchpattern'} did not match anything in searchpage $defs{$strip}{'searchpage'}\n" }
				$addr = "unavail-nomatch";
			} else {
				$addr = $defs{$strip}{'baseurl'} . "${$defs{$strip}{'matchpart'}}";
			}
		}
		
	} elsif ($defs{$strip}{'type'} eq "generate") {
		$addr = $defs{$strip}{'imageurl'};
		$addr = $defs{$strip}{'baseurl'} . $addr;
	}
	
	unless ($addr =~ m/^http:\/\//io || $addr =~ m/^unavail/io) { $addr = "http://" . $addr }
	
	push(@strips,"$strip;$defs{$strip}{'name'};$defs{$strip}{'homepage'};$addr;$defs{$strip}{'updated'};$defs{$strip}{'referer'}")
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
		chomp;
		s/^\s+//o; s/\s+$//o; s/#(.*)//o;

		if (!$sectype) {
			if (/^strip\s+(\w+)$/io)
			{
				$strip = $1;
				$sectype = "strip";
			}
			elsif (/^class\s+(.*)$/io)
			{
				$class = $1;
				$sectype = "class";
			}
			elsif (/^group\s+(.*)$/io)
			{
				$group = $1;
				$sectype = "group";
			}
			elsif (/^(.*)/io)
			{
				die "Unknown keyword '$1' at $options{'defs_file'} line $line\n";
			}
		}
		elsif (/^end$/io)
		{
			if ($sectype eq "class")
			{
				undef $class
			}		
			elsif ($sectype eq "strip")
			{
				if ($defs{$strip}{'useclass'}) {
					my $using_class = $defs{$strip}{'useclass'};
					
					for (qw(homepage searchpage searchpattern baseurl imageurl referer)) {
						if ($classes{$using_class}{$_} and !$defs{$strip}{$_}) {
							my $classvar = $classes{$using_class}{$_};
							$classvar =~ s/(\$[0-9])/$defs{$strip}{$1}/g;
							$classvar =~ s/\$strip/$strip/g;
							$defs{$strip}{$_} = $classvar;
						}
					}
				
					for (qw(type matchpart updated)) {
						if ($classes{$using_class}{$_} and !$defs{$strip}{$_}) {
							$defs{$strip}{$_} = $classes{$using_class}{$_};
						}
					}	
				}	
						
				#substitute auto vars for real vals here/set defaults
				unless ($defs{$strip}{'updated'})    {$defs{$strip}{'updated'} = "daily"}
				unless ($defs{$strip}{'searchpage'}) {$defs{$strip}{'searchpage'} = $defs{$strip}{'homepage'}}
				unless ($defs{$strip}{'referer'})    {
					if ($defs{$strip}{'searchpage'}) {
						$defs{$strip}{'referer'} = $defs{$strip}{'searchpage'}
					} else {
						$defs{$strip}{'referer'} = $defs{$strip}{'homepage'}
					}
				}
				
				for (qw(homepage searchpage searchpattern imageurl baseurl referer)) {
					#other vars in definition
					# could do without 'if defined..' if not running under -w
					if ($defs{$strip}{$_}) {$defs{$strip}{$_} =~ s/\$(name|homepage|searchpage|searchpattern|imageurl|baseurl|referer)/$defs{$strip}{$1}/g}
				}			
				
				for (qw(homepage searchpage searchpattern imageurl baseurl referer)) {
					#dates
					# could do without 'if defined..' if not running under -w
					if ($defs{$strip}{$_}) { $defs{$strip}{$_} =~ s/(\%(-?)[a-zA-Z])/strftime("$1", @localtime_today)/ge }
				}
				
				
				#sanity check vars
				for (qw(name homepage type)) {
					unless ($defs{$strip}{$_})     { die "Error: strip $strip has no '$_' value\n" }
				}
				
				for (qw(homepage searchpage baseurl imageurl)){	
					if ($defs{$strip}{$_} and $defs{$strip}{$_} !~ m/^http:\/\//io) {
						die "Error: strip $strip has invalid $_\n"
					}
				}
				
				if ($defs{$strip}{'type'} eq "search") {
					unless ($defs{$strip}{'searchpattern'}) { die "Error: strip $strip has no 'searchpattern' value\n" }
					unless ($defs{$strip}{'matchpart'})     { die "Error: strip $strip has no 'matchpart' value\n" }
				} else {
					unless ($defs{$strip}{'imageurl'})      { die "Error: strip $strip has no 'imageurl' value\n" }
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
				
				unless ($groups{$group}{'desc'}) { $groups{$group}{'desc'} = "[No description]"}
				
				undef $group;
			}
			
			undef $sectype;
		}
		elsif ($sectype eq "class") {
			if (/^homepage\s+(.+)$/io) {
				my $val = $1;
				$classes{$class}{'homepage'} = $val;
			}
			elsif (/^type\s+(.+)$/io)
			{
				my $val = $1;
				unless ($val =~ m/^(search|generate)$/io) { die "Error: invalid types at $options{'defs_file'} line $line\n" }
				$classes{$class}{'type'} = $val;
			}
			elsif (/^searchpage\s+(.+)$/io)
			{
				my $val = $1;
				$classes{$class}{'searchpage'} = $val;
			}
			elsif (/^searchpattern\s+(.+)$/io)
			{
				$classes{$class}{'searchpattern'} = $1;
			}
			elsif (/^matchpart\s+(.+)$/o)
			{
				my $val = $1;
				unless ($val =~ m/^\d+$/io) { die "Error: invalid matchpart at $options{'defs_file'} line $line\n" }
				$classes{$class}{'matchpart'} = $val;
			}
			elsif (/^baseurl\s+(.+)$/io)
			{
				my $val = $1;
				$classes{$class}{'baseurl'} = $val;
			}
			elsif (/^imageurl\s+(.+)$/io)
			{
				my $val = $1;
				$classes{$class}{'imageurl'} = $val;
			}
			elsif (/^referer\s+(.+)$/io)
			{
				$classes{$class}{'referer'} = $1;
			}
			elsif (/^updated\s+(.+)$/io)
			{
				$classes{$class}{'updated'} = $1;
			}
			elsif (/^(.+)(\s+?)/io)
			{
				die "Unknown keyword '$1' at $options{'defs_file'} line $line\n";
			}
		}
		elsif ($sectype eq "strip") {
			if (/^name\s+(.+)$/io)
			{
				$defs{$strip}{'name'} = $1;
			}
			elsif (/^useclass\s+(.+)$/io)
			{
				$defs{$strip}{'useclass'} = $1;
			}
			elsif (/^homepage\s+(.+)$/io) {
				my $val = $1;
				$defs{$strip}{'homepage'} = $val;
			}
			elsif (/^type\s+(.+)$/io)
			{
				my $val = $1;
				unless ($val =~ m/^(search|generate)$/io) { die "Error: invalid type at $options{'defs_file'} line $line\n" }
				$defs{$strip}{'type'} = $val;
			}
			elsif (/^searchpage\s+(.+)$/io)
			{
				my $val = $1;
				$defs{$strip}{'searchpage'} = $val;
			}
			elsif (/^searchpattern\s+(.+)$/io)
			{
				$defs{$strip}{'searchpattern'} = $1;
			}
			elsif (/^matchpart\s+(.+)$/o)
			{
				my $val = $1;
				unless ($val =~ m/^\d+$/io) { die "Error: invalid matchpart at $options{'defs_file'} line $line\n" }
				$defs{$strip}{'matchpart'} = $val;
			}
			elsif (/^baseurl\s+(.+)$/io)
			{
				my $val = $1;
				$defs{$strip}{'baseurl'} = $val;
			}
			elsif (/^imageurl\s+(.+)$/io)
			{
				my $val = $1;
				$defs{$strip}{'imageurl'} = $val;
			}
			elsif (/^updated\s+(.+)$/io)
			{
				$defs{$strip}{'updated'} = $1;
			}
			elsif (/^referer\s+(.+)$/io)
			{
				$defs{$strip}{'referer'} = $1;
			}
			elsif (/^(\$[0-9])\s+(.+)$/io)
			{
				$defs{$strip}{$1} = $2;
			}
			elsif (/^(.+)(\s+?)/io)
			{
				die "Unknown keyword '$1' at $options{'defs_file'} line $line, in strip $strip\n";
			}
		} elsif ($sectype eq "group") {
			if (/^desc\s+(.+)$/io)
			{
				$groups{$group}{'desc'} = $1;
			}
			elsif (/^include\s+(.+)$/io)
			{
				$groups{$group}{'strips'} .= join(';', split(/\s+/, $1)) . ";";
			}
			elsif (/^(.+)(\s+?)/io)
			{
				die "Unknown keyword '$1' at $options{'defs_file'} line $line, in group $group\n";
			}
		}
			
		
		
		$line++;
	}
	
	# Post-processing validation
	for $group (keys %groups) {
		for ( split(/;/, $groups{$group}{'strips'}) ) {
			unless ($defs{$_}) {
				die "Error: group $group includes non-existant strip $_\n";
			}
		}
	}
	
}
