package EISanalytics;
#
# Access information about the analytics environment
#

use strict;
use Fcntl 'O_RDWR', 'O_CREAT';
use Getopt::Long;

BEGIN {
    use Exporter ();
    our ($VERSION, @ISA, @EXPORT, %EXPORT_TAGS);
    $VERSION = "1.8";

    @ISA = qw( Exporter );
    @EXPORT = qw(
    	&analytics_url
    	&dump_db
    	&get_db
    	&option
    	&option_add
    	&options_list
    	&options_print
    	&oxml_print
    	&set_db
    	&site_name
    );
    %EXPORT_TAGS = ();

    # Reorder list of dbm suppliers
    @AnyDBM_File::ISA = qw( DB_File GDBM_File NDBM_File SDBM_File ODBM_File );
}
use AnyDBM_File;

# List of urls of servers
# Index is '<site>:<test or prod>:<disp or objt or rept>'
my %url = (
    'camo:prod:disp' => 'http://ecamowdp2360.rnd.ericsson.se:8099/service-dispatch/object',

    'cnsh:prod:disp' => 'http://ecnshwdp2001.rnd.ericsson.se:8099/service-dispatch/object',

    'deac:prod:disp' => 'http://edeacwdp2001.rnd.ericsson.se:8099/service-dispatch/object',

    'seka:prod:disp' => 'http://esekamw026.epk.ericsson.se:8099/service-dispatch/object',

    'seki:prod:disp' => 'http://analyticski.rnd.ericsson.se:8099/service-dispatch/object',

    'seki:test:disp' => 'http://esekitest361.rnd.ericsson.se:8099/service-dispatch/object',
    'seki:test:objt' => 'http://esekitest361.rnd.ericsson.se/Inovia365Web/Upload?type=1',
    'seki:test:rept' => 'http://esekitest361.rnd.ericsson.se/Inovia365Web/Upload?type=reportImport&parentId=666',

    'seli:prod:disp' => 'http://eseliwdp23it02.rnd.ericsson.se:8099/service-dispatch/object',

    'seln:prod:disp' => 'http://eselnwdp2023.rnd.ericsson.se:8099/service-dispatch/object',

    'ussj:prod:disp' => 'http://eussjwdp2006.rnd.ericsson.se:8099/service-dispatch/object',
);

my %search = (
    'ca*'  => 'camo',
    'cn*'  => 'cnsh',
    'de*'  => 'deac',
    'fi*'  => 'seki',
    'pocc' => 'seki',
    'semo' => 'seln',
    'se*'  => 'seki',
    'usaa' => 'camo',
    'us*'  => 'ussj',
    '????' => 'seki',
    '*'    => 'seki'
);

# My db
my $db = '/var/tmp/EISanalytics/logData';
my %data;
my $SUBSEP = "\034";

my $site;

my @tags = ();

# Options
my %opts = (
	'debug'		=> 0,
	'delimiter'	=> '|',
	'tags'		=> \@tags,
	'oxml'		=> 0,
);

my %opt_dflt = (
);

my %opt_defs = (
	'b|db=s'		=> \$db,
	'c|cache=i'		=> \$opts{'cache'},
	'D|debug+'		=> \$opts{'debug'},
	'h|help!'		=> \$opts{'help'},
	'O|object=s'		=> \$opts{'object'},
	'oxml'			=> \$opts{'oxml'},
	'p'			=> sub { $opts{'test'} = 0 },
	's|site=s'		=> \$opts{'site'},
	'T|tag=s@'		=> \@tags,
	't|test!'		=> \$opts{'test'},
	'U|url=s'		=> \$opts{'url'},
	'V|version!'		=> \$opts{'version'},
);

my %opt_desc = (
	'-b or --db <file name>'	=> 'Set the database file name',
	'-c or --cache <count>'		=> 'Set the size of the connection cache',
	'-D or --debug'			=> 'Enable debugging, each one increases verbosity',
	'-h or --help'			=> 'Display help',
	'-O or --object <object name>'	=> 'Set the object name',
	'--oxml'			=> 'Print oxml object description',
	'-p or --notest'		=> 'Opposite to test i.e. production',
	'-s or --site <site name>'	=> 'Set the site to use',
	'-T or --tag <name>'		=> 'Add a tag, multiple tags may be added',
	'-t or --test'			=> 'Set test mode, use test dispatcher',
	'-U or --url <url>'		=> 'URL to use for dispatch',
	'-V or --version'		=> 'Print program version',
);

my %opt2def_tag = (
	'cache'		=> [ 'c|cache=i',	'-c or --cache <count>'		],
	'db'		=> [ 'b|db=s',		'-b or --db <file name>'	],
	'debug'		=> [ 'D|debug+',	'-D or --debug'			],
	'help'		=> [ 'h|help!',		'-h or --help'			],
	'object'	=> [ 'O|object=s',	'-O or --object <object name>'	],
	'oxml'		=> [ 'oxml',		'--oxml'			],
	'p'		=> [ 'p',		'-p or --notest'		],
	'site'		=> [ 's|site=s',	'-s or --site <site name>'	],
	'tag'		=> [ 'T|tag=s@',	'-T or --tag <name>'		],
	'test'		=> [ 't|test!',		'-t or --test'			],
	'url'		=> [ 'U|url=s',		'-U or --url <url>'		],
	'version'	=> [ 'V|version!',	'-V or --version'		],
);

my $need_opts = 1;

END {}

# Return the site code
sub site_name() {
	if (!defined($site) || $site eq "") {
		my $site_opt = option('site');
		my $site_db = get_db('site', '????');
		if (defined($site_opt)) {
			$site = $site_opt;
		}
		elsif ($site_db ne '????') {
			$site = $site_db;
		}
		elsif (defined($ENV{'SITE'})) {
			$site = $ENV{'SITE'};
		}
		else {
			$site = '????';
		}
	}
	return $site;
}

# Calculate the appropriate dispatcher
sub analytics_url($;$$) {
	my $t = (shift) ? 'test' : 'prod';	# test or production server
	my $s = shift;	# optional site parameter
	my $r = shift;	# optional role parameter disp, objt or rept

	return $opts{'url'} if (defined($opts{'url'}));

	$s = site_name() if (!defined($s));
	$r = 'disp' if (!defined($r));
	my $tr = ':' . $t . ':' . $r;

	return $url{$s.$tr} if (defined($url{$s.$tr}));

	$s = $search{$s} if (defined($search{$s}));
	return $url{$s.$tr} if (defined($url{$s.$tr}));	# site default

	$s =~ s/^(..).*$/$1*/;
	$s = $search{$s} if (defined($search{$s}));
	return $url{$s.$tr} if (defined($url{$s.$tr}));	# country default

	return $url{$search{'*'}};		# Global default
}

# Connect to database
sub tie_db() {
	my $dbDir = $db;
	$dbDir =~ s%/[^/]+$%%;	# Trim file name
	if (! -d $dbDir) {
		mkdir($dbDir, 0755) or die "Can't mkdir($dbDir):$!";
	}
	tie(%data, 'AnyDBM_File', $db, O_RDWR|O_CREAT, 0644);
}

# Lookup key in db
sub get_db($;$) {
	my $key = shift;
	my $dflt = shift;

	tie_db() if (!tied(%data));

	if (defined($data{$key})) {
		my @ret = split(/$SUBSEP/, $data{$key});
		return wantarray() ? @ret : join(" ", @ret);
	}
	return $dflt;
}

# Dump contents of db
sub dump_db() {
	my %ret = ();
	my $d = $opts{'delimiter'};

	tie_db() if (!tied(%data));

	foreach my $i (keys %data) {
		$ret{$i} = $data{$i};
		$ret{$i} =~ s/$SUBSEP/$d/go;		# convert from internal format
	}
	return %ret;
}

# Set entry in db
sub set_db($;@) {
	my $key = shift;
	my $val;
	$val = join($SUBSEP, @_) if (scalar(@_) > 0);

	tie_db() if (!tied(%data));
	if (defined($val)) {
		$data{$key} = $val;
	}
	else {
		delete($data{$key});
	}
}

# Return options
sub option(;$$) {
	my $key = shift;
	my $dflt = shift;

	if ($need_opts) {
		Getopt::Long::Configure('bundling', 'no_ignore_case');
		Getopt::Long::GetOptions(%opt_defs);
		$need_opts = 0;
	}

	return $opts{$key} if (defined($key) && defined($opts{$key}));
	return $dflt;
}

# Add an option
sub option_add($$$$;$) {
	my $key = shift;		# option name
	my $def = shift;		# definition for GetOptions
	my $tag = shift;		# tag for usage
	my $desc = shift;		# description for usage
	my $dflt = shift;		# optional default value

	$opt_defs{$def} = \$opts{$key};
	$opt_desc{$tag} = $desc;
	$opt2def_tag{$key} = \[ $def, $tag ];
	if (defined($dflt)) {
		$opts{$key} = $dflt;
		$opt_dflt{$tag} = $dflt;
	}
}

# Remove an option
sub option_del($) {
	my $key = shift;

	if (defined($opt2def_tag{$key})) {
		my ($def, $tag) = (@{$opt2def_tag{$key}});
		delete $opt_defs{$def};
		delete $opt_desc{$tag};
	}
	delete $opts{$key};
}

# List of options
sub options_list() { return %opt_desc; }

# Print option list
sub options_print(;$) {
	my $fh = shift;		# output file handle
	$fh = \*STDERR if (!defined($fh));

	my $w = 8;			# tag width
	my @ot = sort {lc($a) cmp lc($b)} keys %opt_desc;	# case independent sorted option tags list
	foreach my $i (@ot) {
		my $l = length($i);
		$w = ($l + 4) & ~3 if ($l >= $w);		# $w is multiple of 4 wider than widest tag
	}
	print $fh "\tOptions:\n";
	foreach my $i (@ot) {
		printf $fh "\t   %-*s %s\n", $w, $i, $opt_desc{$i};
		if (defined($opt_dflt{$i})) {
			my $d = $opt_dflt{$i};
			# Try and see if default id true or false
			$d = $d ? 'true' : 'false' if ($d =~ /^\d+$/ && $i !~ /<.*>/);
			printf $fh "\t   %-*s Default: '%s'\n", $w, "", $d;
		}
	}
	print $fh "\n";
}

# Print OXML object description
sub oxml_print($$;@) {
	my $obj = shift;
	my $desc = shift;

	sub pcRepl($) { return sprintf("%%%02x", ord(shift)) }

	$desc =~ s/([^\w_.!~*() -])/pcRepl($1)/ge;

	printf "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n<Object id=\"%s\" chg=\"0\" crt=\"1376461526077\" decimals=\"0\"\n        desc=\"%s\" error=\"                              \"\n        length=\"0\" row=\"1\" type=\"float\" valueTime=\"0\" vtype=\"3\" warn=\"                              \"\n>\n",
		$obj, $desc;

	# Print fields
	foreach my $row (@_) {
		my ($name, undef, $type, $len, $dec) = @{$row};
		printf "    <Field name=\"%s\" type=\"%s\" length=\"%d\" decimals=\"%d\" />\n",
			$name, $type, $len, $dec;
	};

	print "</Object>\n";
}

1;

__END__

=head1 NAME

EISanalytics - Access information about the EIS Analytics environment

=head1 SYNOPSIS

  use EISanalytics;

=head1 DESCRIPTION

The EISanalytics perl module gives access to common functions useful for writing
Analytics collectors that are site independent.

=head2 Functions

The following functions are exported:

=over

=item C<< site_name() >>

Returns the site_name for the host.

=item C<< analytics_url(<test?> [, site [, role]]) >>

Returns the URL of the analytics server for C<site>.

If C<test?> is true then the test server is returned, otherwise the production
server is returned.

If site is not defined then the output from C<site_name()> is used.

The role parameter is used to determine which server to return. The default value is
B<disp>, the supported roles are:

=over

=item * B<disp> - return the dispatcher url.

=item * B<objt> - return the url for creating objects.

=item * B<rept> - return the url for creating reports.

=back

=item C<< dump_db() >>

Returns a hash with all the keys and values in the database. If a key has multiple
values the they are separated by C<option('delimiter')>.

=item C<< get_db(<key> [, default value]) >>

Returns the value in the database indexed by key. If there is no value the the optional
default is returned.

=item C<< set_db(<key> [,value...]) >>

The list of values is used to update the database entry indexed by key. The key is
deleted from the database if value is missing.

=item C<< option(<key> [, default value]) >>

Returns the option indexed by key or the optional default value if it does not exist.
The key is the same as the long form of the option, C<see option_list()> below.

=item C<< option_add(<key>, <def>, <tag>, <desc> [, default]) >>

Add an option to the options list. The B<key> is the value that will be used to retrieve
the option, B<def> is the definition used by C<Getopt::Long> and B<tag> and B<desc>
are the key and value respectively returned by C<option_list()>. The optional B<default>
is the value return if the option is not present.

=item C<< option_del(<key>) >>

Delete an option from the options list. The B<key> is the value that was be used to retrieve
the option.

=item C<< options_list() >>

Returns a hash with the keys being the option tags and the values being
the option descriptions.

=item C<< options_print([File Handle]) >>

Print the options list to the file handle or STDERR if it is omitted

=item C<< oxml_print(<object>, <description>, <field definition>...) >>

Print the oxml file that defines the object used. The object's name and description
are inserted directly into the object tag. Each field tag is created from a field
description which is in turn an array consisting of the field's name, description, type,
length and number of decimals.

Example:

	oxml_print(
		'myObject', 'Really great stuff',
		['host',  'Machine running test', 'char', 64, 0],
		['users', 'Number of users logged in', 'float', 0, 0]
	);


=back

=head1 AUTHOR

Originally designed and implemented by Michael Salmon <michael.salmon@ericsson.com>.
