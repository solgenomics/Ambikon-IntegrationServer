use strict;
use warnings;

use Test::More;
use JSON::Any;  my $json = JSON::Any->new;

use lib 't/lib';
use Ambikon::IntegrationServer::Test::Proxy qw/ test_proxy filter_env /;

# test a basic conf with 1 backend
test_proxy(
    conf => <<'',
<subsite loopy>
  internal_url   http://$host:$ambikon_port/foo/bar
  external_path  /
</subsite>

    backends => [
        sub {
            my $env = shift;

            return [ 302, ['Location' => '/foo/bar/baz'], undef] if $env->{PATH_INFO} =~ m!/redirect$!;

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
        $mech->get('/');
        is( $mech->status, 500 );
        diag $mech->content;
    },
  );
