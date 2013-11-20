package EISlogger;
#
# Support routines for logging
#

use strict;
use Fcntl 'O_RDWR', 'O_CREAT';
use Getopt::Long;
use Sys::Syslog;

BEGIN {
    use Exporter ();
    our ($VERSION, @ISA, @EXPORT, %EXPORT_TAGS);
    $VERSION = "1.0";

    @ISA = qw( Exporter );
    @EXPORT = qw(
    	&dump_db
    	&get_db
    	&option
    	&option_add
    	&options_list
    	&options_print
    	&set_db
    	&syslog_array
    	&syslog_priority
    );
    %EXPORT_TAGS = ();

    # Reorder list of dbm suppliers
    @AnyDBM_File::ISA = qw( DB_File GDBM_File NDBM_File SDBM_File ODBM_File );
}
use AnyDBM_File;

# My db
my $db = '/var/tmp/EISanalytics/logData';
my %data;
my $SUBSEP = "\034";

# Syslog parameters
my $facility = 'user';
my $severity = 'notice';
my $tag = "ART";

# Options
my %opts = (
	'debug'		=> 0,
	'delimiter'	=> '|',
);

my %opt_dflt = (
	'-b or --db <file name>'	=> $db,
	'-F or --facility <name>'	=> $facility,
	'-P or --priority <priority>'	=> $facility . '.' . $severity,
	'-S or --severity <name>'	=> $severity,
	'-T or --tag <tag>'		=> $tag,
);

my %opt_defs = (
	'b|db=s'		=> \$db,
	'D|debug+'		=> \$opts{'debug'},
	'f|facility=s'		=> \$facility,
	'h|help!'		=> \$opts{'help'},
	'p'			=> sub { $opts{'test'} = 0 },
	'P|priority=s'		=> sub { syslog_priority($_[1]) },
	's|severity=s'		=> \$severity,
	't|test!'		=> \$opts{'test'},
	'T|tag=s'		=> \$tag,
	'V|version!'		=> \$opts{'version'},
);

my %opt_desc = (
	'-b or --db <file name>'	=> 'Set the database file name',
	'-D or --debug'			=> 'Enable debugging, each one increases verbosity',
	'-f or --facility <name>'	=> 'Set the facility for syslog messages',
	'-h or --help'			=> 'Display help',
	'-p or --notest'		=> 'Opposite to test i.e. production',
	'-P or --priority <priority>'	=> 'Priority for syslog i.e. "facility.severity"',
	'-s or --severity <name>'	=> 'Set the severity for syslog messages',
	'-t or --test'			=> 'Set test mode',
	'-T or --tag <tag>'		=> 'Mark every line in the log with the specified tag',
	'-V or --version'		=> 'Print program version',
);

my %opt2def_tag = (
	'db'		=> [ 'b|db=s',		'-b or --db <file name>'	],
	'debug'		=> [ 'D|debug+',	'-D or --debug'			],
	'facility'	=> [ 'f|facility=s',	'-f or --facility <name>'	],
	'help'		=> [ 'h|help!',		'-h or --help'			],
	'p'		=> [ 'p',		'-p or --notest'		],
	'priority'	=> [ 'P|priority=s',	'-P or --priority <priority>'	],
	'severity'	=> [ 's|severity=s',	'-s or --severity <name>'	],
	'tag'		=> [ 'T|tag=s',		'-T or --tag <tag>'		],
	'test'		=> [ 't|test!',		'-t or --test'			],
	'version'	=> [ 'V|version!',	'-V or --version'		],
);

my $need_opts = 1;

END {}

# Set the facility or severity
sub syslog_priority(;$$) {
	my $old = $facility . '.' . $severity;
	if (defined($_[1])) {
		$facility = shift;
		$severity = shift;
	}
	elsif (defined($_[0])) {
		$_ = shift;
		if (/^\s*(\w+)\W+(\w+)\s*$/) {
			$facility = $1;
			$severity = $2;
		}
	}
	return $old;
}

# Set the syslog tag
sub syslog_tag(;$) {
	my $old = $tag;
	if (defined($_[0])) {
		$tag = shift;
	}
	return $old;
}

# Send an array to syslog
sub syslog_array(@) {
	openlog($tag, 'ndelay', $facility);
	syslog($severity, $_) foreach (@_);
	closelog();
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
		# special default
		$opts('test') = -t STDIN;
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

__END__

=head1 NAME

EISlogger - help routines for sending messages to syslog

=head1 SYNOPSIS

use EISlogger;

=head1 DESCRIPTION

The EISlogger module contains routines useful for sending messages to syslog.

It also has routines for administering a database that can be used to save information
between invocations of a test script.

=head2 Options

The following options are available:

=head2 Options

The following options are available:

=over

=item C<< -b or --db <file name> >>

Set the database file name

=item C<< -p or --notest >>

Opposite to test i.e. production.

=item C<< -s or --site <site name> >>

Set the site to use.

=item C<< -t or --test >>

Set test mode.

B<N.B.> if the standard input of the script is a terminal then test mode is
automatically selected.

=item C<< -T or --tag <tag> >>

Mark every line in the log with the specified tag.

=item C<< -V or --version >>

Display version of program.

=back

=head1 AUTHOR

Originally designed and implemented by Michael Salmon <michael.salmon@ericsson.com>.
