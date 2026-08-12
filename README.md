# Description

This Perl script downloads the URL for the current comic of various strips that
are available online, and outputs these URLs to an HTML file. This enables you
to view all of your favorite strips at once, instead of visiting several
different websites.

Dailystrips downloads each image and save a copy of it locally.

How to use it:

Create a directory (such as /home/user/dailystrips/) in which to store
the downloaded images and output files.

Add a line like the following to your user’s crontab:

dailystrips --basedir /home/user/dailystrips all

Of course, change /home/user/dailystrips to the exact directory that you
created. You should change the "all" to reflect just the strips you want to
see.

By default, the program calls the output file 'dailystrips-YYYY.MM.DD' and
creates 'index.html' as a symlink to this, so that you can make a bookmark
to index.html in your web browser that will always take you to the latest
page.  If you need to change this, you'll have to edit the script.

For scheduling the time that dailystrips runs, you'll have to consider your
time zone.  I have found that running at 0600 EST (-0500) works well for my
strips (see the contents of group 'andrew').  You may have to experiment a
little to find the best time for the specific strips you download. One idea
is to create a crontab entry to run dailystrips early in the morning and
then a few hours later if the strips aren't all available at one time.

# Requirements

dailystrips requires the `HTTP::Request`, `Date::Time`, `LWP::UserAgent`,
and `POSIX` modules. See www.cpan.org if you don't have them installed
already.

# Installation

Run the following as root:

`perl install.pl`

This will install the definitions file to `/usr/share/dailystrips`, the
documentation to `/usr/share/doc/dailystrips-VERSION`, and the scripts to
`/usr/bin`. Use `perl install.pl --help` for more info and options.

Once dailystrips is installed, you may run the program by typing:

`dailystrips`

For personal installations (no root access), copy `dailystrips` and
`strips.def` to the directory of your choice. Since dailystrips uses
`/usr/share/dailystrips/strips.def` by default, you will need to specify the
definition file with the `--defs FILE` option.
	
# Usage

'dailystrips [stripname(s)]' will print to STDOUT an HTML page with image links
to the latest strip. These links are to the strip's webserver.
'dailystrips --help' lists all available options. --list shows the available
strips and groups. Strip names can specified as listed. Groups must be preceeded
with an '@' symbol.

# Adding new strips

The strips.def file should be relatively self-explanatory. (see README.DEFS for
detailed information). If you are adding several strips from the same site that
share a common format, please create a class for that site. In addition, please
try to pick a method of determining the most current URL possible (i.e. don't
search if it's possible to predict - we don't want to get old strips if running
early in the morning and a site hasn't updated the static page yet) Also, when
you add a new strip, I'd appreciate it if you could send me the definition so
I can add it to the distribution.

# Personal definition file

Users may create a file called ".dailystrips.defs" in their home directory.
Syntax is exactly the same as the main strips.def file. Personal files will be
processed after the main file. This means that classes set in the main file are
available for use in users' files. Also note that any entries (classes, strips,
and groups) in users' files with the same name as entries in the main will take
precedence.

# *Notice*

Keep in mind that this program is for personal use only, as making
the output publicly available on the internet constitutes copyright infringement
without permission from the strips' authors. If you're running it on a personal
webserver that can be accessed fron the internet (even if it's not specifically
public), make sure you set up restrictions so that only you have access to it -
some publishers (Keenspot, Exclusive Content) seem to be checking their
webserver logs for dailystrips users and will come after you in a rather nasty
fashion if it even looks like you're using dailystrips to make a public website.

# Copyright info

This program Copyright (C) 2001 Andrew Medico <amedico@amedico.dhs.org>, and
(C) 2026 Reuben Thomas <rrt@sc3d.org>. All rights reserved. This program is
free software; you may redistribute it and/or modify it under the terms of
the GNU GPL, Version 2.
