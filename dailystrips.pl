#!/usr/bin/perl

#
# Program Summary:
#
# Name:             dailystrips.pl
# Description:      creates an HTML page containing a number of online comics, with an easily exensible framework
# Author:           Andrew Medico <amedico@amedico.dhs.org>
# Created:          23 Nov 2000, 23:33 EST
# Last Modified:    27 July 2001 01:23 EST
# Current Revision: 1.0.16-pre4
#


# Set up
use strict;
no strict qw(refs);

use LWP::UserAgent;
use HTTP::Request;
use POSIX qw(strftime);
use Getopt::Long;


# Variables
my (%options, $version, $time_today, @localtime_today, @localtime_yesterday, @localtime_tomorrow, $long_date, $short_date,
    $short_date_yesterday, $short_date_tomorrow, @get, @strips, %defs, $known_strips, %groups, $known_groups, %classes, $val,
    $link_tomorrow, $no_dateparse, @base_dirparts);

$version = "1.0.16-pre4";

$time_today = time;


# Get options
GetOptions(\%options, 'quiet|q','verbose','output=s','local|l','noindex',
	'archive|a','dailydir|d','stripdir','save|s','date=s',
	'new|n','defs=s','nopersonal','basedir=s','list','proxy=s',
	'proxyauth=s','noenvproxy','nospaces','useragent=s','version|v','help|h') or exit 1;

	
# Process options:
#  Note: Blocks have been ordered so that we only do as much as absolutely
#  necessary if an error is encountered (i.e. do not load defs if --version
#  specified)

# Help and version override anything else
if ($options{'help'}) { print <<END_HELP;
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
                             (DATE is parsed by Date::Parse function)
  -n  --new                  if today's file and yesterday's file for a strip
                             are the same, does not symlink to save space
                             (local mode only, required on non-*NIX platforms)
      --defs=FILE            Use alternate strips definition file
      --nopersonal           Ignore ~/.dailystrips.defs
      --basedir=DIR          Work in specified directory instead of current
                             directory (program will look here for previous HTML
                             files, etc. and save new files here)
      --list                 List available strips
      --proxy=host:port      Uses specified HTTP proxy server (overrides
                             environment proxy, if set)
      --proxyauth=user:pass  Sets username and password for proxy server
      --noenvproxy           Ignores the http_proxy environment variable, if set
      --nospaces             Removes spaces from image filenames (local mode
      --useragent="STRING"   Set User-Agent: header to STRING (default is none)
                             only)
  -v  --version              Prints version number

Bugs and comments to amedico\@amedico.dhs.org
END_HELP
#/#kwrite's syntax higlighting is buggy.. this preserves my sanity	
	exit;
}

if ($options{'version'}) {
		print "dailystrips version $version\n";
		exit;
}


# Date::Parse must be loaded before using --date
eval "use Date::Parse";
if ($@ ne "") {
	warn "Warning: Could not load Date::Parse module. --date option cannot be used\n";
	$no_dateparse = 1;
}

if ($options{'date'}) {
	if ($no_dateparse) {
		die "Error: cannot use --date - Date::Parse not installed\n";
	}
	
	unless ($time_today = str2time($options{'date'})) {
		die "Error: invalid date specified\n";
	}
}


# setup time variables (needed during defs parsing)
@localtime_today = localtime $time_today;
$long_date = strftime("\%A, \%B \%-e, \%Y", @localtime_today);
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

unless ($options{'nopersonal'}) {
	my $personal_defs = ((getpwuid($>))[7]) . "/.dailystrips.defs";
	if (-e $personal_defs) {
		&get_defs($personal_defs);
	}
}

$known_strips = join('|', sort keys %defs);
$known_groups = join('|', sort keys %groups);


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

#Set proxy
if ($options{'proxy'}) {
		$options{'proxy'} =~ m/^(http:\/\/)?(.*?):(.+?)\/?$/i;
		unless ($2 and $3) {
			die "Error: incorrectly formatted proxy server ('http://server:port' expected)\n";
		}
				
		$options{'proxy'} = "http://$2:$3";
}

if (!$options{'noenvproxy'} and !$options{'proxy'} and $ENV{'http_proxy'} ) {
	$ENV{'http_proxy'} =~ m/(http:\/\/)?(.*?):(.+?)\/?$/i;
	unless ($2 and $3) {
		die "Error: incorrectly formatted proxy server environment variable\n('http://server:port' expected)\n";
	}
			
	$options{'proxy'} = "http://$2:$3";
}

if ($options{'proxyauth'}) {
	unless ($options{'proxyauth'} =~ m/^.+?:.+?$/) {
			die "Error: incorrectly formatted proxy credentials ('user:pass' expected)\n";
	}		
}


if ($options{'basedir'}) {
	unless (chdir $options{'basedir'}) {
		die "Error: could not change directory to $options{'basedir'}\n";
	}
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
	warn "dailystrips $version starting:\n"
}


# Report proxy settings
if ($options{'proxy'}) {
	if ($options{'verbose'}) {
		warn "Using proxy server $options{'proxy'}\n";
	}
	
	if ($options{'verbose'} and $options{'proxy_auth'}) {
		warn "Using proxy server authentication\n";
	}
}


if ($options{'local'}) {
	unless ($options{'quiet'}) {
		warn "Operating in local mode\n";
	}
	
	if ($options{'dailydir'}) {
		unless ($options{'quiet'}) {
			warn "Operating in daily directory mode\n";
		}
		
		unless (-d $short_date) {
			unless(mkdir ($short_date, 0755)) {
				die "Error: could not create today's directory ($short_date/)\n";
			}
		}
		
		unless(open(STDOUT, ">$short_date/dailystrips-$short_date.html")) {
			die "Error: could not open HTML file ($short_date/dailystrips-$short_date.html) for writing\n";
		}
		
		system("rm -f dailystrips-$short_date.html;ln -s $short_date/dailystrips-$short_date.html dailystrips-$short_date.html");
	} else {
		unless(open(STDOUT, ">dailystrips-$short_date.html")) {
			die "Error: could not open HTML file (dailystrips-$short_date.html) for writing\n";
		}
	}

	unless ($options{'date'}) {
		unless ($options{'noindex'}) {
			system("rm -f index.html;ln -s dailystrips-$short_date.html index.html")
		}
	}

	if ($options{'archive'}) {
	
		unless (-e "archive.html") {
			# Doesn't exist.. create
			open(ARCHIVE, ">archive.html") or die "Error: could not create archive.html\n";
			print ARCHIVE
"<html>

<head>
        <title>dailystrips archive</title>
</head>

<body bgcolor=\"#ffffff\" text=\"#000000\" link=\"#0000ff\" vlink=\"#ff00ff\" alink=\"#ff0000\">

<p align=\"center\">
<font face=\"helvetica,arial\" size=\"14pt\">dailystrips archive</font>
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
					unless(open(ARCHIVE, ">archive.html")) {
						die "Error: could open archive.html for writing\n";
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
				 warn "Warning: could open dailystrips-$short_date_yesterday.html for writing\n";
			}
		} else {
			warn "Warning: did not find any tag in previous day's file to make today's link\n";
		}
	} else {
		warn "Warning: could not open dailystrips-$short_date_yesterday.html for reading\n";
	}


} elsif ($options{'output'}) {
	unless ($options{'quiet'}) {
		warn "Writing to file $options{'output'}\n";
	}
	
	unless (open(STDOUT, ">$options{'output'}")) {
		die "Error: Could not open output file ($options{'output'}) for writing\n";
	}
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

#"#kwrite's syntax higlighting is buggy.. this preserves my sanity

if ($options{'local'} and !$options{'quiet'}) {
	if ($options{'verbose'}) {
		warn "\nDownloading strip files:\n"
	} else {
		print STDERR "Downloading strip files...";
	}
}

for (@strips) {
	my ($strip, $name, $homepage, $img_addr, $updated, $referer, $prefetch, $provides) = split(/;/, $_);
	my ($img_line, $local_name, $image, $ext);
	my ($local_name_yesterday);
	
	if ($options{'verbose'} and $options{'local'}) {
		warn "Downloading strip file for " . lc((split(/;/, $_))[0]) . "\n";
	}
	
	if ($img_addr =~ "^unavail") {
		if ($options{'verbose'}) {
			warn "Error: $strip: could not retrieve URL\n";
		}
		
		$img_line = "[Error - unable to retrieve URL]";
	} else {
		if ($options{'local'}) {
			# local mode - download strips
			$img_addr =~ m/http:\/\/(.*)\/(.*)\.(.*)$/;
			if (defined $3) { $ext = ".$3" }
			
			if ($options{'stripdir'}) {
 				$local_name_yesterday = "$name/$short_date_yesterday$ext";
 				$local_name = "$name/$short_date$ext";
 				unless ( -d $strip) {
 					mkdir $name, 0755;
 				}
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
				$local_name_yesterday =~ s/\s+//g;
				$local_name =~ s/\s+//g;
			}

			if ($options{'save'} and  -e $local_name) {
				# strip already exists - skip download
				$img_addr = $local_name;
				$img_addr =~ s/ /\%20/go;
				$img_line = "<img src=\"$img_addr\" alt=\"$name\">";
			} else {
				# need to download
				$image = &http_get($img_addr, $referer, $prefetch);
				
				if ($image =~ m/^ERROR/) {
					if ($options{'verbose'}) {
						warn "Error: $strip: could not download strip\n";
					}
					
					$img_line = "[Error - unable to download image]";
				} else {
					if (-l $local_name) {
						# in case today's file is a symlink to yesterday's
						unlink $local_name;
					}

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
#"#kwrite's syntax highlighting is buggy.. this preserves my sanity
if ($options{'local'} and !$options{'quiet'}) {
	if ($options{'verbose'}) {
		warn "Downloading strip files: done\n"
	} else {
		warn "done\n"
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

#"// # kwrite's syntax highlighting is buggy.. this preserves my sanity

sub http_get {
	my ($url, $referer, $prefetch) = @_;
	my ($request, $response, $status);
	
	my $headers = new HTTP::Headers;
	$headers->proxy_authorization_basic(split(/:/, $options{'proxyauth'}));
	$headers->referer($referer);
	
	my $ua = LWP::UserAgent->new;
	$ua->agent($options{'useragent'});
	$ua->proxy('http', $options{'proxy'});
	
	#get prefetch url first
	if ($prefetch ne "") {
		$request = HTTP::Request->new('GET', $prefetch, $headers);
		$response = $ua->request($request);
	
		($status = $response->status_line()) =~ s/^(\d+)/$1:/;

		if ($response->is_error()) {
			if ($options{'verbose'}) {
				warn "Error: could not download prefetch URL $prefetch: $status\n";
			}
			
			return "ERROR: $status";
		}
	}
	
	# main request
	$request = HTTP::Request->new('GET', $url, $headers);				
	$response = $ua->request($request);
	($status = $response->status_line()) =~ s/^(\d+)/$1:/;

	if ($response->is_error()) {
		if ($options{'verbose'}) {
			warn "Error: could not download $url: $status\n";
		}
		
		return "ERROR: $status";
	} else {
		return $response->content;
	}
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

		if ($page =~ m/^ERROR/) {
			if ($options{'verbose'}) {
				warn "Error: $strip: could not download searchpage $defs{$strip}{'searchpage'}\n";
			}
			
			$addr = "unavail-server";
		} else {
			$page =~ m/$defs{$strip}{'searchpattern'}/si;
			
			unless (${$defs{$strip}{'matchpart'}}) {
				if ($options{'verbose'}) {
					warn "Error: $strip: searchpattern $defs{$strip}{'searchpattern'} did not match anything in searchpage $defs{$strip}{'searchpage'}\n";
				}
				
				$addr = "unavail-nomatch";
			} else {
				$addr = $defs{$strip}{'baseurl'} . "${$defs{$strip}{'matchpart'}}" . $defs{$strip}{'urlsuffix'};
			}
		}
		
	} elsif ($defs{$strip}{'type'} eq "generate") {
		$addr = $defs{$strip}{'imageurl'};
		$addr = $defs{$strip}{'baseurl'} . $addr;
	}
	
	unless ($addr =~ m/^(http:\/\/|unavail)/io) { $addr = "http://" . $addr }
	
	push(@strips,"$strip;$defs{$strip}{'name'};$defs{$strip}{'homepage'};$addr;$defs{$strip}{'updated'};$defs{$strip}{'referer'};$defs{$strip}{'prefetch'}");
}

sub get_defs {
	my $defs_file = shift;
	my ($strip, $class, $sectype, $group);
	my (@strips, %nostrips, @okstrips);
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
		s/#(.*)//; s/^\s+//; s/\s+$//;
		
		next if $_ eq "";
		
		if (!$sectype) {
			if (/^strip\s+(\w+)$/i)
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
					for (qw(homepage searchpage searchpattern baseurl imageurl urlsuffix referer prefetch)) {
						if ($classes{$using_class}{$_} and !$defs{$strip}{$_}) {
							my $classvar = $classes{$using_class}{$_};
							$classvar =~ s/(\$[0-9])/$defs{$strip}{$1}/g;
							$classvar =~ s/\$strip/$strip/g;
							$defs{$strip}{$_} = $classvar;
						}
					}
				
					for (qw(type matchpart updated provides)) {
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
					if ($defs{$strip}{$_} and $defs{$strip}{$_} !~ m/^http:\/\//io) {
						die "Error: strip $strip has invalid $_\n"
					}
				}
				
				if ($defs{$strip}{'type'} eq "search") {
					unless ($defs{$strip}{'searchpattern'}) {
						die "Error: strip $strip has no 'searchpattern' value in $defs_file\n";
					}
					
					unless ($defs{$strip}{'matchpart'}) {
						die "Error: strip $strip has no 'matchpart' value in $defs_file\n";
					}
				} else {
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
				unless ($1 =~ m/^(search|generate)$/io) {
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
				unless ($1 =~ m/^(\d)$/) {
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
			elsif (/^updated\s+(.+)$/i)
			{
				$classes{$class}{'updated'} = $1;
			}
			elsif (/^provides\s+(.+)$/i)
			{
				unless ($1 =~ m/^(any|latest)$/i) {
					die "Error: invalid 'provides' at $defs_file line $line\n";
				}
				
				$classes{$class}{'provides'} = $1;
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
				$defs{$strip}{'useclass'} = $1;
			}
			elsif (/^homepage\s+(.+)$/i) {
				$defs{$strip}{'homepage'} = $1;
			}
			elsif (/^type\s+(.+)$/i)
			{
				unless ($1 =~ m/^(search|generate)$/i) {
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
				unless ($1 =~ m/^(\d+)$/) {
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
			elsif (/^updated\s+(.+)$/i)
			{
				$defs{$strip}{'updated'} = $1;
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
				unless ($1 =~ m/^(any|latest)$/i) {
					die "Error: invalid 'provides' at $defs_file line $line\n";
				}
				
				$defs{$strip}{'provides'} = $1;
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
}