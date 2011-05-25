package #hide from PAUSE
  Ambikon::IntegrationServer::Test::Proxy;
use strict;
use warnings;

use Test::TCP;
use Plack::Loader;

use base 'Exporter';
our @EXPORT_OK = ( 'test_proxy', 'filter_env' );

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
    my $configuration = ref $args{conf}
        ? $args{conf}->( \@servers )
        : eval qq|"$args{conf}"|;
    die $@ if $@;

    # make a temp catalyst config file to feed it
    my $temp_conf;
    if ( $configuration ) {
        $temp_conf = File::Temp->new( SUFFIX => '.conf' );
        $temp_conf->print( $configuration );
        $temp_conf->close;
        $ENV{CATALYST_CONFIG} = $temp_conf->filename;
    }

    # start a catalyst server
    my $ambikon_server = Test::TCP->new(
        code => sub {
            my ( $port ) = @_;
            local $ENV{PLACK_SERVER} = 'Standalone';
            my $plack = Plack::Loader->auto( port => $port, host => $host );
            require Ambikon::IntegrationServer;
            Ambikon::IntegrationServer->setup_engine('PSGI');
            $plack->run( sub { Ambikon::IntegrationServer->run(@_) } );
        },
      );

    local $ENV{CATALYST_SERVER} = 'http://localhost:'.$ambikon_server->port;

    my $mech = Ambikon::IntegrationServer::Test::WWWMechanize->new( catalyst_app => 'Ambikon::IntegrationServer' );

    $args{client}->( $mech );
}

# takes an env hashref and filters out psgi vars (many of which can't
# be represented in JSON)
sub filter_env {
    my %env = %{+shift};
    for ( keys %env ) {
        delete $env{$_} if /^psgi/;
    }
    return \%env;
}


1;
