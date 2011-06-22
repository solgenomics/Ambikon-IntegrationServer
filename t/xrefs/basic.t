use strict;
use warnings;

use Test::More;
use IO::String;
use Data::Dump;

use lib 't/lib';
use Ambikon::IntegrationServer::Test::Proxy qw/ test_proxy filter_env /;

test_proxy(
    conf => <<'',
<subsite foo_bar>
  internal_url   http://$host:$port/monkeys
  external_path  /foo
</subsite>

    backends => [
        sub {
            my $env = shift;

            my $response = qq|{ "twee": "zee", "query": "$env->{QUERY_STRING}" }|;

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
        $mech->get_ok('/ambikon/xrefs/search?q=cromulence');
        $mech->content_contains( '"zee"', 'got xref response from subsite' );
    },
  );


done_testing;

