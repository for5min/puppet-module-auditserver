  package debug360;
 
use lib "/usr/lib/perl5/vendor_perl/5.8.8";
  use strict;
  use warnings;
  use URI; 
  use LWP 5.64;
 
  our $VERSION = '1.00';
 
  use base 'Exporter';
 
  our @EXPORT = qw(debug360);
 
  sub debug360 {
    my %args = (
      message        => 'No message was passed to debug360',
      date        => localtime(),
      command        => 'No command was passed to debug360',
      object    => 'No object was passed to debug360',
      @_
    );

      print("command = ", $args{command}, " date = ", $args{date}," object = ", $args{object}, " message = ", $args{message}, "\n");
  

  	my $browser = LWP::UserAgent->new;

  	my $url = URI->new( 'http://esekiwdp360.rnd.ericsson.se:20002/Ericssoni360Web/Dispatcher' );
    	# makes an object representing the URL

  	$url->query_form(  # And here the form data pairs:
		'object'    => 'ErrorLog',
    		'TargetObject'    => $args{object},
    		'Command' => $args{command},
    		'longdate' => $args{date},
    		'Message' => $args{message},
  	);

  	my $response = $browser->get($url);
	print "Response is: \n" . $response->decoded_content . "\n";
 }
  1;
