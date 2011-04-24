use strict;
use warnings;

use Test::More;

use IO::String;
use JSON::Any;  my $json = JSON::Any->new;
use URI;

use lib 't/lib';
use Ambikon::IntegrationServer::Test::Proxy qw/ test_proxy filter_env /;

# test a basic conf with 1 backend
test_proxy(
    conf => <<'',
<subsite foo_bar>
  internal_url   http://$host:$port/monkeys
  external_path  /foo
</subsite>

    backends => [
        sub {
            my $env = shift;
            my $response = $json->encode({
                hello => "Hello world!\n",
                env => filter_env( $env ),
                input => $env->{'psgi.input'} ? do { local $/; $env->{'psgi.input'}->getline } : undef,
              });

            return [
                200,
                [ 'Content-type' => 'text/html',
                  'Content-length' => length($response),
                  'X-bar'  => 'fogbat',
                  'X-zee'  => 'zaz',
                ],
                IO::String->new( \$response ),
              ];
        },
      ],

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
        { my $response = $json->decode( $mech->content );
          is ref($response), 'HASH', 'successfully decoded response'
              or diag explain $response;
          my $request_env = $response->{env};
          is $request_env->{HTTP_X_NOGGIN}, 'bumbumchicken', 'headers from user request passed through proxy';
          is $request_env->{HTTP_X_CROMULENCE}, 'confirmed', 'headers from user request passed through proxy';
        }

        {
          # POST with application/x-www-form-urlencoded
          my %post_input = ( really_long => 'REALLY_LONG_STRING_' x 20_000,
                             foo => 'bugaboo & something else! ',
                             'twee zee!' => 3,
                           );
          $mech->post_ok( '/foo/bar/bonk', \%post_input );
          $mech->content_contains( 'Hello world' );
          my $response = $json->decode( $mech->content );
          my %decoded_input = URI->new('?'.$response->{input})->query_form;
          is_deeply \%decoded_input, \%post_input, 'POST with application/x-www-form-urlencoded works';
        }
    },
  );

done_testing;
exit;

