#!/usr/bin/perl

#
# Program Summary:
#
# Name:             dailystrips
# Description:      creates an HTML page containing a number of online comics, with an easily exensible framework
# Author:           Andrew Medico <amedico@amedico.dhs.org>
# Maintainer:       Reuben Thomas <rrt@sc3d.org>
# Created:          23 Nov 2000, 23:33 EST
#


# Set up
use strict;
no strict qw(refs);

use LWP::UserAgent;
use HTTP::Request;
use POSIX qw(strftime);
use Getopt::Long;
use File::Copy;


# Variables
my (%options, $version, $time_today, @localtime_today, @localtime_yesterday, @localtime_tomorrow, $long_date, $short_date,
    $short_date_yesterday, $short_date_tomorrow, @get, @strips, %defs, $known_strips, %groups, $known_groups, %classes, $val,
    $link_tomorrow, $no_dateparse, @base_dirparts);

$version = "1.0.29pre1";

$time_today = time;


# Get options
GetOptions(\%options, 'quiet|q','verbose','noindex',
	'archive|a','dailydir|d','stripdir','save|s','nostale','date=s',
	'new|n','defs=s','nopersonal','basedir=s','list',
	'useragent=s','version|v','help|h',
	'random','stripnav','titles=s',
	'retries=s','clean=s','updates=s','noupdates') or exit 1;

# Process options:
#  Note: Blocks have been ordered so that we only do as much as absolutely
#  necessary if an error is encountered (i.e. do not load defs if --version
#  specified)

# Help and version override anything else
if ($options{'help'}) {
	print
"Usage: $0 [OPTION] STRIPS
STRIPS can be a mix of strip names and group names
(group names must be preceeded by an '\@' symbol)
'all' may be used to retrieve all known strips,
or use option --list to list available strips and groups

Options:
  -q  --quiet                Turn off progress messages		
      --verbose              Turn on extra progress information, overrides -q
      --list                 List available strips
      --random               Download a random strip
      --defs FILE            Use alternate strips definition file
      --nopersonal           Ignore ~/.dailystrips.defs
      --updates              Read updated defs from FILE instead of
                             ~/.dailystrips-updates.def
      --noupdates            Ignore updated defs file 
      --stripnav             Add links for navigation within the page
      --titles STRING        Customize HTML output
      --noindex              Disable symlinking current page to index.html
  -a  --archive              Generate archive.html as a list of all days,
  -d  --dailydir             Create a separate directory for each day's images
      --stripdir             Create a separate directory for each strip's
                             images
  -s  --save                 If it appears that a particular strip has been
                             downloaded, does not attempt to re-download it
      --nostale              If a new strip is not available, displays an error
                             in the HTML output instead of showing the old image
      --date DATE            Use value DATE instead of local time
                             (DATE is parsed by Date::Parse function)
      --basedir DIR          Work in specified directory instead of current
                             directory (program will look here for previous HTML
                             file and save new files here, etc.)
      --useragent STRING     Set User-Agent: header to STRING (default is none)
      --retries NUM          When downloading items, retry NUM times instead of
                             default 3 times
      --clean NUM            Keep only the latest NUM days of files; remove all
                             older files
  -v  --version              Print version number
";

	print "\nBugs and comments to rrt\@sc3d.org\n";

	exit;
}

if ($options{'version'}) {
		print "dailystrips version $version\n";
		exit;
}


if ($options{'date'}) {
	eval "require Date::Parse";
	if ($@ ne "") {
		die "Error: cannot use --date - Date::Parse not installed\n";
	} else {
		import Date::Parse;
	}

	unless ($time_today = str2time($options{'date'})) {
		die "Error: invalid date specified\n";
	}
}


# setup time variables (needed during defs parsing)
@localtime_today = localtime $time_today;
$long_date = strftime("\%A, \%B \%e, \%Y", @localtime_today);
$short_date = strftime("\%Y.\%m.\%d", @localtime_today);
@localtime_yesterday = localtime($time_today - ( 24 * 60 * 60 ));
$short_date_yesterday = strftime("\%Y.\%m.\%d", @localtime_yesterday);
@localtime_tomorrow = localtime ($time_today + 24 * 60 * 60);
$short_date_tomorrow = strftime("\%Y.\%m.\%d", @localtime_tomorrow);


# Get strip definitions now - info used below
unless ($options{'defs'}) {
	$options{'defs'} = '/usr/share/dailystrips/strips.def';
}

&get_defs($options{'defs'});


# Load updated defs file
unless (defined $options{'updates'})
{
        $options{'updates'} = &get_homedir() . "/.dailystrips-updates.def";
}


unless($options{'noupdates'})
{
	if (-r $options{'updates'}) {
		&get_defs($options{'updates'});
	}
}

# Get system configurable strip definitions now
unless (! -r '/etc/dailystrips.defs') {
	&get_defs('/etc/dailystrips.defs');
}

unless ($options{'nopersonal'}){
	my $personal_defs = &get_homedir()  . "/.dailystrips.defs";
	if (-r $personal_defs) {
		&get_defs($personal_defs);
	}
}

$known_strips = join('|', sort keys %defs);
$known_groups = join('|', sort keys %groups);

if ($options{'random'}) {
	my @known_strips_array = keys %defs;

	push(@get, $known_strips_array[(rand $#known_strips_array)]);

	undef @known_strips_array;
} else {
	# Only strips/groups to download remain in @ARGV
	# Unconfigured options were already trapped by Getopts with an 'unknown option'
	# error
	for (@ARGV) {
		if (/^($known_strips|all)$/io) {
			if ($_ eq "all") {
				push (@get, split(/\|/, $known_strips));
			} else {
				push(@get, $_);
			}
		} elsif (/^@/) {
			if (/^@($known_groups)$/io) {
				push(@get, split(/;/, $groups{$1}{'strips'}));
			} else {
				die "Error: unknown group: $_\n";
			}
		} else {
			die "Error: unknown strip: $_\n";
		}
	}
}

if ($options{'list'}) {
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
}

if ($options{'dailydir'} and $options{'stripdir'}) {
		die "Error: --dailydir and --stripdir cannot be used together\n";
}


# Handle/validate other options
if ($options{'clean'} =~ m/\D/) {
	die "Error: 'clean' value must be numeric\n";
}

if ($options{'retries'} =~ m/\D/) {
	die "Error: 'retries' value must be numeric\n";
}

unless ($options{'retries'}) {
	$options{'retries'} = 3;
}


if ($options{'basedir'}) {
	unless (chdir $options{'basedir'}) {
		die "Error: could not change directory to $options{'basedir'}\n";
	}
}

if ($options{'titles'}) {
	$options{'titles'} .= " ";
}

unless (@get) {
	die "Error: no strip specified (--list to list available strips)\n";
}


# verbose overrides quiet
if ($options{'verbose'} and $options{'quiet'}) {
	undef $options{'quiet'};
}


# Un-needed vars
undef $known_strips; undef $known_groups; undef $val;


# Go
unless ($options{'quiet'}) {
	warn "dailystrips $version starting:\n";
}


if ($options{'dailydir'}) {
	unless ($options{'quiet'}) {
		warn "Operating in daily directory mode\n";
	}
		
	unless (-d $short_date) {
		unless (mkdir ($short_date, 0755)) {
			die "Error: could not create today's directory ($short_date/)\n";
		}
	}
}
	
unless (open(STDOUT, ">dailystrips-$short_date.html")) {
	die "Error: could not open HTML file (dailystrips-$short_date.html) for writing\n";
}

unless ($options{'date'}) {
	unless ($options{'noindex'}) {
		unlink("index.html");
		system("ln -s dailystrips-$short_date.html index.html");
	}
}

if ($options{'archive'}) {
	
	unless (-e "archive.html") {
		# Doesn't exist.. create
		open(ARCHIVE, ">archive.html") or die "Error: could not create archive.html\n";
		print ARCHIVE
		  "<html>

<head>
	<title>$options{'titles'}dailystrips archive</title>
</head>

<body bgcolor=\"#ffffff\" text=\"#000000\" link=\"#0000ff\" vlink=\"#ff00ff\" alink=\"#ff0000\">

<p align=\"center\">\n

<font face=\"helvetica,arial\" size=\"14pt\">$options{'titles'}dailystrips archive</font>

</p>

<p>
<font face=\"helvetica,arial\">
<!--insert below-->
</font>
</p>

</body>

</html>";
		close(ARCHIVE);
	}

	open(ARCHIVE, "<archive.html") or die "Error: could not open archive.html for reading\n";
	my @archive = <ARCHIVE>;
	close(ARCHIVE);

	unless (grep(/<a href="dailystrips-$short_date.html">/, @archive)) {
		for (@archive) {
			if (s/(<!--insert below-->)/$1\n<a href="dailystrips-$short_date.html">$long_date<\/a><br>/) {
				unless (open(ARCHIVE, ">archive.html")) {
					die "Error: could not open archive.html for writing\n";
				}

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
			warn "Warning: could not open dailystrips-$short_date_yesterday.html for writing\n";
		}
	} else {
		warn "Warning: did not find any tag in previous day's file to make today's link\n";
	}
} else {
	warn "Warning: could not open dailystrips-$short_date_yesterday.html for reading\n";
}

# Download image URLs
unless ($options{'quiet'}) {
	if ($options{'verbose'}) {
		warn "\nRetrieving URLS:\n"
	} else {
		print STDERR "\nRetrieving URLS..."
	}
}
for (@get) {
	if ($options{'verbose'}) { warn "Retrieving URL for $_\n" }
	&get_strip($_);
}
unless ($options{'quiet'}) {
	if ($options{'verbose'}) {
		warn "Retrieving URLS: done\n"
	} else {
		warn "done\n"
	}
}

if (-e "dailystrips-$short_date_tomorrow.html") {
	$link_tomorrow = " | <a href=\"dailystrips-$short_date_tomorrow.html\">Next day</a>"
} else {
	$link_tomorrow = "<!--nextday-->"
}


# Generate HTML page
my $topanchor;
if ($options{'stripnav'}) {
	$topanchor = "\n<a name=\"top\">\n";
}

print
"<html>

<head>
	<title>$options{'titles'}dailystrips for $long_date</title>
</head>

<body bgcolor=\"#ffffff\" text=\"#000000\" link=\"#ff00ff\">
$topanchor
<center>
	<font face=\"helvetica\" size=\"+2\"><b><u>$options{'titles'}dailystrips for $long_date</u></b></font>
</center>

<p><font face=\"helvetica\">
&lt; <a href=\"dailystrips-$short_date_yesterday.html\">Previous day</a>$link_tomorrow";
	
if ($options{'archive'}) {
	print " | <a href=\"archive.html\">Archives</a>";
}

print
" &gt;
</font></p>
";

if ($options{'stripnav'}) {
	print "<font face=\"helvetica\">Strips:</font><br>\n";
	for (@strips) {
		my ($strip, $name) = (split(/;/, $_))[0,1];
		print "<a href=\"#$strip\">$name</A>&nbsp;&nbsp;";
	}
	print "\n<br><br>";
}

print "\n\n<table border=\"0\">\n";

if (!$options{'quiet'}) {
	if ($options{'verbose'}) {
		warn "\nDownloading strip files:\n"
	} else {
		print STDERR "Downloading strip files...";
	}
}

for (@strips) {
	my ($strip, $name, $homepage, $img_addr, $referer, $prefetch, $artist) = split(/;/, $_);
	my ($img_line, $local_name, $local_name_dir, $local_name_file, $local_name_ext, $image, $ext,
	   $local_name_yesterday, $local_name_yesterday_dir, $local_name_yesterday_file, $local_name_yesterday_ext);
	
	if ($options{'verbose'}) {
		warn "Downloading strip file for " . lc((split(/;/, $_))[0]) . "\n";
	}
	
	if ($img_addr =~ "^unavail") {
		if ($options{'verbose'}) {
			warn "Error: $strip: could not retrieve URL\n";
		}

		$img_line = "[Error - unable to retrieve URL]";
	} else {
		# download strips
		$img_addr =~ /https?:\/\/(.*)\/(.*)\.(.*?)([?&].+)?$/;
		if (defined $3) {
			$ext = ".$3";
		}

		# prepare file names
		if ($options{'stripdir'}) {
			$local_name_yesterday = "$name/$short_date_yesterday$ext";
			$local_name_yesterday_dir = "$name/";
			$local_name_yesterday_file = $short_date_yesterday;
			$local_name_yesterday_ext = $ext;
 				
			$local_name = "$name/$short_date$ext";
			$local_name_dir = "$name/";
			$local_name_file = "$short_date";
			$local_name_ext = "$ext";
		} elsif ($options{'dailydir'}) {
			$local_name_yesterday = "$short_date_yesterday/$name-$short_date_yesterday$ext";
			$local_name_yesterday_dir = "$short_date_yesterday/";
			$local_name_yesterday_file = "$name-$short_date_yesterday";
			$local_name_yesterday_ext = "$ext";
				
			$local_name = "$short_date/$name-$short_date$ext";
			$local_name_dir = "$short_date/";
			$local_name_file = "$name-$short_date";
			$local_name_ext = "$ext";
		} else {
			$local_name_yesterday = "$name-$short_date_yesterday$ext";
			$local_name_yesterday_dir = "./";
			$local_name_yesterday_file = "$name-$short_date_yesterday";
			$local_name_yesterday_ext = "$ext";
				
			$local_name = "$name-$short_date$ext";
			$local_name_dir = "./";
			$local_name_file = "$name-$short_date";
			$local_name_ext = "$ext";
		}
			
		# do ops that depend on file name
		if ($options{'stripdir'}) {
			unless (-d $local_name_dir) {
				mkdir $local_name_dir, 0755;
			}
		}
									
		if ($options{'save'} and  -e $local_name) {
				# already have a suitable local file - skip downloading
			$img_addr = $local_name;
			$img_addr =~ s/ /\%20/go;
			if ($options{'stripnav'}) {
				$img_line = "<img src=\"$img_addr\" alt=\"$name\"><br><a href=\"#top\">Return to top</a>";
			} else {
				$img_line = "<img src=\"$img_addr\" alt=\"$name\">";
			}
		} else {
			# need to download
			if ($prefetch) {
				if (&http_get($prefetch, $referer) =~ m/^ERROR/) {
					warn "Error: $strip: could not download prefetch URL\n";
					$image = "ERROR";
				} else {
					$image = &http_get($img_addr, $referer);
				}
			} else {
				$image = &http_get($img_addr, $referer);
				#$image = &http_get($img_addr, "");
			}
				
			if ($image =~ /^ERROR/) {
				# couldn't get the image
				# FIXME: what to do if a file for the day has already been
				# downloaded, but downloading fails when script is run again
				# that day? maybe reuse existing file instead of throwing
				# error?
				if (-e $local_name) {
					# an image file for today already exists.. jump to outputting code
					#warn "DEBUG: couldn't download strip, but we already have it\n";
					goto HAVE_IMAGE;
				} else {
					if ($options{'verbose'}) {
						warn "Error: $strip: could not download strip\n";
					}
				}
				
				$img_line = "[Error - unable to download image]";
			} else {
			      HAVE_IMAGE:
				# got the image
				# FIXME: only download to .tmp if earlier file exists
				open(IMAGE, ">$local_name.tmp");
				binmode(IMAGE);
				print IMAGE $image;
				close(IMAGE);
				
				if (system("diff \"$local_name_yesterday\" \"$local_name.tmp\" >/dev/null 2>&1") == 0) {
					# same strip as yesterday
					system("mv","$local_name.tmp","$local_name");
						
					if ($options{'nostale'}) {
						$img_line = "[Error - new strip not available]";
					} else {
						$img_addr = $local_name;
						$img_addr =~ s/ /\%20/go;
						if ($options{'stripnav'}) {
							$img_line = "<img src=\"$img_addr\" alt=\"$name\"><br><a href=\"#top\">Return to top</a>";
						} else {
							$img_line = "<img src=\"$img_addr\" alt=\"$name\">";
						}
					}
				} elsif (-e $local_name and system("diff \"$local_name\" \"$local_name.tmp\" >/dev/null 2>&1") == 0) {
					# already downloaded the same strip earlier today
					unlink("$local_name.tmp");

					$img_addr = $local_name;
					$img_addr =~ s/ /\%20/go;
					if ($options{'stripnav'}) {
						$img_line = "<img src=\"$img_addr\" alt=\"$name\"><br><a href=\"#top\">Return to top</a>";
					} else {
						$img_line = "<img src=\"$img_addr\" alt=\"$name\">";
					}
				} else {
					# completely new strip
					#  possible to get here by:
					#   -downloading a strip for the first time in a day
					#   -downloading an updated strip that replaces an old one downloaded at
					#    an earlier time on the same day
					system("mv","$local_name.tmp","$local_name");
						
					$img_addr = $local_name;
					$img_addr =~ s/ /\%20/go;
					if ($options{'stripnav'}) {
						$img_line = "<img src=\"$img_addr\" alt=\"$name\"><br><a href=\"#top\">Return to top</a>";
					} else {
						$img_line = "<img src=\"$img_addr\" alt=\"$name\">";
					}
				}
			}
		}
	}
		
	if ($artist) {
		$artist = " by $artist";
	}
	
	my $stripanchor;
	if ($options{'stripnav'}) {
		$stripanchor = "<a name=\"$strip\">";
	}

	print
"	<tr>
		<td>
			<font face=\"helvetica\" size=\"+1\"><b>$stripanchor<a href=\"$homepage\">$name</a>$artist</b></font>
		</td>
	</tr>
	<tr>
		<td>
			$img_line
			<p>&nbsp;</p>
		</td>
	</tr>
";
}

if (!$options{'quiet'}) {
	if ($options{'verbose'}) {
		warn "Downloading strip files: done\n"
	} else {
		warn "done\n"
	}
}

print
"</table>

<p><font face=\"helvetica\">
&lt; <a href=\"dailystrips-$short_date_yesterday.html\">Previous day</a>$link_tomorrow";

if ($options{'archive'}) {
	print " | <a href=\"archive.html\">Archives</a>";
}

print
" &gt;
</font></p>

<font face=\"helvetica\">Generated by dailystrips $version</font>

</body>

</html>
";

# Clean out old files, if requested
if ($options{'clean'}) {
	unless ($options{'quiet'}) {
		print STDERR "Cleaning files older than $options{'clean'} days...";
	}
	
	unless (system("perl -S dailystrips-clean --quiet $options{'clean'}")) {
		unless ($options{'quiet'}) {
			print STDERR "done\n";
		}
	}
	else {
		warn "failed\nWarning: could not run dailystrips-clean script\n";
	}
	
	
}

sub http_get {
	my ($url, $referer) = @_;
	my ($request, $response, $status);

	# default value
	#unless ($retries) {
	#	$retries = 3;
	#}

	if ($referer eq "") {$referer = $url;}

	my $headers = new HTTP::Headers;
	$headers->referer($referer);
	
	my $ua = LWP::UserAgent->new;
	$ua->agent($options{'useragent'});
	
	for (1 .. $options{'retries'}) {
		# main request
		$request = HTTP::Request->new('GET', $url, $headers);				
		$response = $ua->request($request);
		($status = $response->status_line()) =~ s/^(\d+)/$1:/;

		if ($response->is_error()) {
			if ($options{'verbose'}) {
				warn "Warning: could not download $url: $status (attempt $_ of $options{'retries'})\n";
			}
		} else {
			return $response->content;
		}
	}

	# if we get here, URL retrieval completely failed
	warn "Warning: failed to download $url\n";
	return "ERROR: $status";
}

sub get_strip {
	my ($strip) = @_;
	my ($page, $addr);
	
	if ($options{'date'} and $defs{$strip}{'provides'} eq "latest") {
		if ($options{'verbose'}) {
			warn "Warning: strip $strip not compatible with --date, skipping\n";
		}
		
		next;
	}
	
	if ($defs{$strip}{'type'} eq "search") {
		$page = &http_get($defs{$strip}{'searchpage'});

		if ($page =~ /^ERROR/) {
			if ($options{'verbose'}) {
				warn "Error: $strip: could not download searchpage $defs{$strip}{'searchpage'}\n";
			}
			
			$addr = "unavail-server";
		} else {
			$page =~ /$defs{$strip}{'searchpattern'}/si;
			my @regexmatch;
			for (1..9) {
				$regexmatch[$_] = ${$_};
				#warn "regex match #$_: ${$_}\n";	
			}

			unless (${$defs{$strip}{'matchpart'}}) {
				if ($options{'verbose'}) {
					warn "Error: $strip: searchpattern $defs{$strip}{'searchpattern'} did not match anything in searchpage $defs{$strip}{'searchpage'}\n";
				}
				
				$addr = "unavail-nomatch";
			} else {
				my $match = ${$defs{$strip}{'matchpart'}};

				if ($defs{$strip}{'imageurl'}) {
					$addr = $defs{$strip}{'imageurl'};
					$addr =~ s/\$match_(\d)/$regexmatch[$1]/ge;
					$addr =~ s/\$match/$match/ge;
				} else {
					$addr = $defs{$strip}{'baseurl'} . $match . $defs{$strip}{'urlsuffix'};
				}
			}
		}
		
	} elsif ($defs{$strip}{'type'} eq "generate") {
		$addr = $defs{$strip}{'baseurl'} . $defs{$strip}{'imageurl'};
	}
	
	unless ($addr =~ /^(https?:\/\/|unavail)/io) { $addr = "http://" . $addr }
	
	push(@strips,"$strip;$defs{$strip}{'name'};$defs{$strip}{'homepage'};$addr;$defs{$strip}{'referer'};$defs{$strip}{'prefetch'};$defs{$strip}{'artist'}");
}

sub get_defs {
	my $defs_file = shift;
	my ($strip, $class, $sectype, $group);
	my $line;
	
	unless(open(DEFS, "<$defs_file")) {
		die "Error: could not open strip definitions file $defs_file\n";
	}
	
	my @defs_file = <DEFS>;
	close(DEFS);
	
	if ($options{'verbose'}) {
		warn "Loading definitions from file $defs_file\n";
	}
	
	for (@defs_file) {
		$line++;
		
		chomp;
		s/#(.*)//; s/^\s*//; s/\s*$//;

		next if $_ eq "";

		if (!$sectype) {
			if (/^strip\s+(\S+)$/i)
			{
				if (defined ($defs{$1}))
				{
					undef $defs{$1};
				}
				
				$strip = $1;
				$sectype = "strip";
			}
			elsif (/^class\s+(.*)$/i)
			{
				if (defined ($classes{$1}))
				{
					undef $classes{$1};
				}
							
				$class = $1;
				$sectype = "class";
			}
			elsif (/^group\s+(.*)$/i)
			{
				if (defined ($groups{$1}))
				{
					undef $groups{$1};
				}
			
				$group = $1;
				$sectype = "group";
			}
			elsif (/^(.*)/)
			{
				die "Error: Unknown keyword '$1' at $defs_file line $line\n";
			}
		}
		elsif (/^end$/i)
		{
			if ($sectype eq "class")
			{
				undef $class
			}		
			elsif ($sectype eq "strip")
			{
				if ($defs{$strip}{'useclass'}) {
					my $using_class = $defs{$strip}{'useclass'};
					
					# import vars from class
					for (qw(homepage searchpage searchpattern baseurl imageurl urlsuffix referer prefetch artist)) {
						if ($classes{$using_class}{$_} and !$defs{$strip}{$_}) {
							my $classvar = $classes{$using_class}{$_};
							$classvar =~ s/(\$[0-9])/$defs{$strip}{$1}/g;
							$classvar =~ s/\$strip/$strip/g;
							$defs{$strip}{$_} = $classvar;
						}
					}
				
					for (qw(type matchpart provides)) {
						if ($classes{$using_class}{$_} and !$defs{$strip}{$_}) {
							$defs{$strip}{$_} = $classes{$using_class}{$_};
						}
					}	
				}	
						
				#substitute auto vars for real vals here/set defaults
				unless ($defs{$strip}{'searchpage'}) {$defs{$strip}{'searchpage'} = $defs{$strip}{'homepage'}}
				unless ($defs{$strip}{'referer'})    {
					if ($defs{$strip}{'searchpage'}) {
						$defs{$strip}{'referer'} = $defs{$strip}{'searchpage'}
					} else {
						$defs{$strip}{'referer'} = $defs{$strip}{'homepage'}
					}
				}
				
				#other vars in definition
				for (qw(homepage searchpage searchpattern imageurl baseurl urlsuffix referer prefetch)) {
					if ($defs{$strip}{$_}) {
						$defs{$strip}{$_} =~ s/\$(name|homepage|searchpage|searchpattern|imageurl|baseurl|referer|prefetch)/$defs{$strip}{$1}/g;
					}
				}			
		
				#dates		
				for (qw(homepage searchpage searchpattern imageurl baseurl urlsuffix referer prefetch)) {
					if ($defs{$strip}{$_}) {
						$defs{$strip}{$_} =~ s/(\%(-?)[a-zA-Z])/strftime("$1", @localtime_today)/ge;
					}
				}
				
				# <code:> stuff
				for (qw(homepage searchpage searchpattern imageurl baseurl urlsuffix referer)) {
					if ($defs{$strip}{$_}) {
						$defs{$strip}{$_} =~ s/<code:(.*?)(?<!\\)>/&my_eval($1)/ge;
					}
				}
				
				#sanity check vars
				for (qw(name homepage type)) {
					unless ($defs{$strip}{$_}) {
						die "Error: strip $strip has no '$_' value\n";
					}
				}
				
				for (qw(homepage searchpage baseurl imageurl)){	
					if ($defs{$strip}{$_} and $defs{$strip}{$_} !~ /^https?:\/\//io) {
						die "Error: strip $strip has invalid $_\n"
					}
				}
				
				if ($defs{$strip}{'type'} eq "search") {
					unless ($defs{$strip}{'searchpattern'}) {
						die "Error: strip $strip has no 'searchpattern' value in $defs_file\n";
					}
					
					unless ($defs{$strip}{'searchpattern'} =~ /\(.+\)/) {
						die "Error: strip $strip has no parentheses in searchpattern\n";
					}
					
					unless ($defs{$strip}{'matchpart'}) {
						#die "Error: strip $strip has no 'matchpart' value in $defs_file\n";
						$defs{$strip}{'matchpart'} = 1;
					}
					
					if ($defs{$strip}{'imageurl'} and ($defs{$strip}{'baseurl'} or $defs{$strip}{'urlsuffix'})) {
						die "Error: strip $strip: cannot use both 'imageurl' at the same time as 'baseurl'\nor 'urlsuffix'\n";
					}
				} elsif ($defs{$strip}{'type'} eq "generate") {
					unless ($defs{$strip}{'imageurl'}) {
						die "Error: strip $strip has no 'imageurl' value in $defs_file\n";
					}
				}
				
				unless ($defs{$strip}{'provides'}) {
					die "Error: strip $strip has no 'provides' value in $defs_file\n";
				}
				
				#debugger
				#foreach my $strip (keys %defs) {
				#	foreach my $key (qw(homepage searchpage searchpattern imageurl baseurl referer prefetch)) {
				#		warn "DEBUG: $strip:$key=$defs{$strip}{$key}\n";
				#	}
				#	#warn "DEBUG: $strip:name=$defs{$strip}{'name'}\n";
				#}
			
				undef $strip;
			}
			elsif ($sectype eq "group")
			{
				chop $groups{$group}{'strips'};
				
				unless ($groups{$group}{'desc'}) {
					$groups{$group}{'desc'} = "[No description]";
				}
				
				undef $group;
			}
			
			undef $sectype;
		}
		elsif ($sectype eq "class") {
			if (/^homepage\s+(.+)$/i) {
				$classes{$class}{'homepage'} = $1;
			}
			elsif (/^type\s+(.+)$/i)
			{
				unless ($1 =~ /^(search|generate)$/io) {
					die "Error: invalid type at $defs_file line $line\n";
				}
				
				$classes{$class}{'type'} = $1;
			}
			elsif (/^searchpage\s+(.+)$/i)
			{
				$classes{$class}{'searchpage'} = $1;
			}
			elsif (/^searchpattern\s+(.+)$/i)
			{
				$classes{$class}{'searchpattern'} = $1;
			}
			elsif (/^matchpart\s+(.+)$/i)
			{
				unless ($1 =~ /^(\d)$/) {
					die "Error: invalid 'matchpart' at $defs_file line $line\n";
				}
				
				$classes{$class}{'matchpart'} = $1;
			}
			elsif (/^baseurl\s+(.+)$/i)
			{
				$classes{$class}{'baseurl'} = $1;
			}
			elsif (/^urlsuffix\s+(.+)$/i)
			{
				$classes{$class}{'urlsufix'} = $1;
			}
			elsif (/^imageurl\s+(.+)$/i)
			{
				$classes{$class}{'imageurl'} = $1;
			}
			elsif (/^referer\s+(.+)$/i)
			{
				$classes{$class}{'referer'} = $1;
			}
			elsif (/^prefetch\s+(.+)$/i)
			{
				$classes{$class}{'prefetch'} = $1;
			}
			elsif (/^provides\s+(.+)$/i)
			{
				unless ($1 =~ /^(any|latest)$/i) {
					die "Error: invalid 'provides' at $defs_file line $line\n";
				}

				$classes{$class}{'provides'} = $1;
			}
			elsif (/^artist\s+(.+)$/i)
			{
				$classes{$class}{'artist'} = $1;
			}
			elsif (/^(.+)\s+?/)
			{
				die "Unknown keyword '$1' at $defs_file line $line\n";
			}
		}
		elsif ($sectype eq "strip") {
			if (/^name\s+(.+)$/i)
			{
				$defs{$strip}{'name'} = $1;
			}
			elsif (/^useclass\s+(.+)$/i)
			{
				unless (defined $classes{$1}) {
					die "Error: strip $strip references invalid class $1 at $defs_file line $line\n";
				}

				$defs{$strip}{'useclass'} = $1;
			}
			elsif (/^homepage\s+(.+)$/i) {
				$defs{$strip}{'homepage'} = $1;
			}
			elsif (/^type\s+(.+)$/i)
			{
				unless ($1 =~ /^(search|generate)$/i) {
					die "Error: invalid 'type' at $defs_file line $line\n";
				}
				
				$defs{$strip}{'type'} = $1;
			}
			elsif (/^searchpage\s+(.+)$/i)
			{
				$defs{$strip}{'searchpage'} = $1;
			}
			elsif (/^searchpattern\s+(.+)$/i)
			{
				$defs{$strip}{'searchpattern'} = $1;
			}
			elsif (/^matchpart\s+(.+)$/i)
			{
				unless ($1 =~ /^(\d+)$/) {
					die "Error: invalid 'matchpart' at $defs_file line $line\n";
				}
				
				$defs{$strip}{'matchpart'} = $1;
			}
			elsif (/^baseurl\s+(.+)$/i)
			{
				$defs{$strip}{'baseurl'} = $1;
			}
			elsif (/^urlsuffix\s+(.+)$/i)
			{
				$defs{$strip}{'urlsuffix'} = $1;
			}
			elsif (/^imageurl\s+(.+)$/i)
			{
				$defs{$strip}{'imageurl'} = $1;
			}
			elsif (/^referer\s+(.+)$/i)
			{
				$defs{$strip}{'referer'} = $1;
			}
			elsif (/^prefetch\s+(.+)$/i)
			{
				$defs{$strip}{'prefetch'} = $1;
			}
			elsif (/^(\$\d)\s+(.+)$/)
			{
				$defs{$strip}{$1} = $2;
			}
			elsif (/^provides\s+(.+)$/i)
			{
				unless ($1 =~ /^(any|latest)$/i) {
					die "Error: invalid 'provides' at $defs_file line $line\n";
				}
				
				$defs{$strip}{'provides'} = $1;
			}
			elsif (/^artist\s+(.+)$/i)
			{
				$defs{$strip}{'artist'} = $1;
			}
			elsif (/^(.+)\s+?/)
			{
				die "Error: Unknown keyword '$1' at $defs_file line $line, in strip $strip\n";
			}
		} elsif ($sectype eq  "group") {
			if (/^desc\s+(.+)$/i)
			{
				$groups{$group}{'desc'} = $1;
			}
			elsif (/^include\s+(.+)$/i)
			{
				$groups{$group}{'strips'} .= join(';', split(/\s+/, $1)) . ";";
			}
			elsif (/^exclude\s+(.+)$/i)
			{
				$groups{$group}{'nostrips'} .= join(';', split(/\s+/, $1)) . ";";
			}
			elsif (/^(.+)\s+?/)
			{
				die "Error: Unknown keyword '$1' at $defs_file line $line, in group $group\n";
			}
		}
	}
	
	# Post-processing validation
	for $group (keys %groups) {
		my (@strips, %nostrips, @okstrips);
		
		if (defined($groups{$group}{'nostrips'})) {
			@strips = sort(keys(%defs));
			foreach (split (/;/,$groups{$group}{'nostrips'})) {
				$nostrips{$_} = 1;
			}
		} else {
			@strips = split(/;/, $groups{$group}{'strips'});
			%nostrips = ();   #empty
		}

		foreach (@strips) {
			unless ($defs{$_}) {
				warn "Warning: group $group references non-existant strip $_\n";
			}
			
			next if ($nostrips{$_});
			push (@okstrips,$_);
		}
		$groups{$group}{'strips'} = join(';',@okstrips);
	}
	
}

sub my_eval {
	my ($code) = @_;
	
	$code =~ s/\\\>/\>/g;
	
	return eval $code;
	#print STDERR "DEBUG: eval returned: " . scalar(eval $code) . ", errors: $!\n";
}

sub get_homedir
{
	return (getpwuid($>))[7];
}
