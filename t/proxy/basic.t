use strict;
use warnings;

use Test::More;
use Test::TCP;

use IO::String;
use JSON::Any;  my $json = JSON::Any->new;
use Plack::Loader;

use lib 't/lib';
use amb_int_mech;

test_proxy(
    conf => <<'',
<subsite foo_bar>
  internal_url   http://$host:$port/monkeys
  external_path  /foo
</subsite>

    backends => sub {
        my $plack_server = shift;
        $plack_server->run(sub {
            my $env = shift;
            my $response = $json->encode({ hello => "Hello world!\n", env => filter_env( $env ) });
            [
                200,
                [ 'Content-type' => 'text/html',
                  'Content-length' => length($response),
                  'X-bar'  => 'fogbat',
                  'X-zee'  => 'zaz',
                ],
                IO::String->new( \$response ),
            ];
        });
    },

    client => sub {
        my $mech = shift;
        $mech->add_header( 'X-noggin' => 'bumbumchicken' );
        $mech->add_header( 'X-cromulence' => 'confirmed' );
        $mech->get_ok( '/foo/bar/baz?fee=fie+fo#fum' );
        $mech->content_contains( 'Hello world' );
        $mech->content_lacks( '#fum' );

        is $mech->response->header('X-bar'), 'fogbat', 'headers from backend passed through proxy';
        is $mech->response->header('X-zee'), 'zaz', 'headers from backend passed through proxy';

        # parse our response JSON and look harder at the env that the request got
        my $response = $json->decode( $mech->content );
        is ref($response), 'HASH', 'successfully decoded response'
           or diag explain $response;
        my $request_env = $response->{env};
        is $request_env->{HTTP_X_NOGGIN}, 'bumbumchicken', 'headers from user request passed through proxy';
        is $request_env->{HTTP_X_CROMULENCE}, 'confirmed', 'headers from user request passed through proxy';
    },
  );

done_testing;
exit;

######## subroutines ######3

sub test_proxy {
    my %args = @_;

    my $host = $args{host} || '127.0.0.1';

    my $backends = $args{backends} or die 'no backends';
    $backends = [ $backends ] unless ref $backends eq 'ARRAY';

    my @servers = map {
        my $backend_code = $_;
        my $test_server = Test::TCP->new(
            code => sub {
                my ( $port ) = @_;
                local $ENV{PLACK_SERVER} = 'Standalone';
                my $plack = Plack::Loader->auto( port => $port, host => $host );
                $backend_code->( $plack );
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
    my $mech = amb_int_mech->new( configuration => $configuration );
    $args{client}->( $mech );
}

sub filter_env {
    my %env = %{+shift};
    for ( keys %env ) {
        delete $env{$_} if /^psgi/;
    }
    return \%env;
}
