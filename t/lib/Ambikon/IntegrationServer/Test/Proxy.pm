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

    # start the backend servers
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

    # start an ambikon server
    my $ambikon_server = Test::TCP->new(
        code => sub {
            my ( $ambikon_port ) = @_;

            my $configuration_text = ref $args{conf}
                ? $args{conf}->( \@servers )
                : do {
                    # set up some additional variables that can interpolate in
                    my $port  = $servers[0]->port;
                    my $port1 = $servers[0]->port;
                    my ( $port2, $port3 );
                    $port2 = $servers[1]->port if $servers[1];
                    $port3 = $servers[2]->port if $servers[2];

                    my $interpolated_text = eval qq|"$args{conf}"|;
                    die $@ if $@;
                    $interpolated_text
                };

            # make a temp catalyst config file to feed the integration
            # server app
            my $temp_conf;
            local $ENV{CATALYST_CONFIG};
            if ( $configuration_text ) {
                $temp_conf = File::Temp->new( SUFFIX => '.conf' );
                $temp_conf->print( $configuration_text );
                $temp_conf->close;
                $ENV{CATALYST_CONFIG} = $temp_conf->filename;
            }

            require Ambikon::IntegrationServer;
            Ambikon::IntegrationServer->setup_engine('HTTP');
            Ambikon::IntegrationServer->run( $ambikon_port );
        },
      );

    # set up a mech to point at the ambikon server
    local $ENV{CATALYST_SERVER} = "http://$host:".$ambikon_server->port;
    my $mech = Ambikon::IntegrationServer::Test::WWWMechanize->new(
        catalyst_app => 'Ambikon::IntegrationServer',
        );

    # call the client code with the configured mech
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
