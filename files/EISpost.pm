package EISpost;
#
# Class for sending data to analytics dispatcher
#

use strict;
use warnings;

use EISanalytics;

use LWP;
use LWP::ConnCache;

BEGIN {
    our ($VERSION, @ISA);
    $VERSION = "1.2";
    @ISA = ()
}

# New object
sub new {
	my $class = shift;
	my %cnf = @_;

	my $test = delete $cnf{'test'};
	my $cache = delete $cnf{'cache'};
	my $ua = LWP::UserAgent->new;
	$ua->conn_cache(LWP::ConnCache->new('total_capacity' => $cache)) if $cache;

	# Instantiate class
	my $self = bless {
		'cache'	=> defined($cache) ? $cache : 0,
		'maps'	=> [],
		'test'	=> defined($test) ? $test : 0,
		'ua'	=> $ua,
	}, $class;

	return $self;
}

# New map for object
sub newMap {
	my $self = shift;
	my $obname = shift;	# Analytics object
	my %map = (
		'object'	=> $obname,
		'value'		=> 0.0,
		'longdate'	=> int(time() * 1000),
	);
	push @{$self->{maps}}, \%map;
	return \%map;
}

# Remove all maps
sub clearMaps {
	my $self = shift;
	$self->{'maps'} = [];
}

# Print map
sub printMap(;$$) {
	my $self = shift;

	my $map = shift;
	$map = ${$self->{maps}}[-1] if (!defined($map));

	my $fh = shift;
	$fh = \*STDOUT if (!defined($fh));

	# calculate key width
	my $w = 0;
	foreach my $i (keys %{$map}) {
		my $l = length($i);
		$w = $l if ($l > $w);
	}

	foreach my $i (sort keys %{$map}) {
		printf $fh "%*s => '%s'\n", $w, $i, ${$map}{$i};
	}
}

# Send data to server
sub post {
	my $self = shift;
	my @xml = ();
	my $url = analytics_url($self->{'test'});

	# Character entities
	my %ent = (
		'&'	=> '&amp;',
		'<' => '&lt;',
		'>' => '&gt;',
	);
	my $entre = join('|', keys %ent);

	if (scalar(@{$self->{'maps'}}) > 0) {
		push @xml, '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
		push @xml, '<mapList>';

		foreach my $map (@{$self->{'maps'}}) {
			my @mx = (' <map>');
			foreach my $i (keys %{$map}) {
				my $v = ${$map}{$i};
				$v = "" if (!defined($v));
				$v =~ s/($entre)/$ent{$1}/ge;
				push @mx, sprintf('<entry><key>%s</key><value>%s</value></entry>', $i, $v);
			}
			push @mx, '</map>';
			push @xml, join('', @mx);
		}

		push @xml, '</mapList>';

		my $req = HTTP::Request->new('POST' => $url);
		$req->content(join("\n", @xml));
		$req->content_type('application/xml');
		return $self->{'ua'}->request($req);
	}

	return undef;
}

1;

__END__

=head1 NAME


=head1 SYNOPSIS

  use EISpost;
  my $eis = EISpost->new();
  my $map = $eis->newMap('test');
  ${$map}{'host'} = $ENV{'HOST'};
  my $resp = $eis->post();
  print "Response is: \n", $resp->decoded_content, "\n" if ($resp->is_error);

=head1 DESCRIPTION

EISpost - help object for sending Analytics object data

=head2 Methods

The following methods are available:

=over

=item C<< new( ['test' => <boolean>], ['cache' => <connection cache size>] >>

Create a new EISpost object, the test option is used to select the dispatcher and
the cache option set the size of the connection cache to be used.

=item C<< newMap(<object name>) >>

This method returns a HASH reference that is used to load the values for a row in the
object defined in the sole parameter. The 'object', 'longtime' and 'value' fields are
loaded at creation but can be overwritten later.

This method can be called multiple times to load several objects at the same time.

=item C<< printMap([map] [, file handle]) >>

Print the contents of a map to a file handle. If omitted the file handle defaults
to STDOUT and the map to the last created.

=item C<< post() >>

Send the maps created using C<newMap()> to the dispatcher defined by the site and test
options.

=item C<< clearMaps() >>

Delete the maps created by C<newMap()>.

=back

=head1 AUTHOR

Originally designed and implemented by Michael Salmon <michael.salmon@ericsson.com>.
