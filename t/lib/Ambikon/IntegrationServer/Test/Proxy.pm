package #hide from PAUSE
  Ambikon::IntegrationServer::Test::Proxy;
use strict;
use warnings;

use Test::TCP;
use Plack::Loader;

use base 'Exporter';
our @EXPORT_OK = 'test_proxy';

use Ambikon::IntegrationServer::Test::WWWMechanize;

sub test_proxy {
    my %args = @_;

    my $host     = $args{host} || '127.0.0.1';
    my $backends = $args{backends} or die 'no backends';
    $backends = [ $backends ] unless ref $backends eq 'ARRAY';

    my @servers = map {
        my $backend_code = $_;
        my $test_server = Test::TCP->new(
            code => sub {
                my ( $port ) = @_;
                local $ENV{PLACK_SERVER} = 'Standalone';
                my $plack = Plack::Loader->auto( port => $port, host => $host );
                $plack->run( $backend_code );
            },
          );
      } @$backends;

    my $port  = $servers[0]->port;
    my $port1 = $servers[0]->port;
    my ( $port2, $port3 );
    $port2 = $servers[1]->port if $servers[1];
    $port3 = $servers[2]->port if $servers[2];

    my $configuration = ref $args{conf} ? $args{conf}->( \@servers )
                                        : eval qq|"$args{conf}"|;
    die $@ if $@;
    my $mech = Ambikon::IntegrationServer::Test::WWWMechanize->new( configuration => $configuration );
    $args{client}->( $mech );
}


1;
