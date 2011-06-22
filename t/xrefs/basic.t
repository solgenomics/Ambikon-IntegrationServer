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
<subsite baz>
 internal_url   http://$host:$port2/
 external_path  /fog
</subsite>

    backends => [
        sub {
            my $env = shift;
            [ 200,
              [ 'Content-type' => 'text/html',
                'X-bar'  => 'fogbat',
                'X-zee'  => 'zaz',
              ],
              [ qq|{ "twee": "zee", "query": "$env->{QUERY_STRING}" }| ],
            ];
        },

        sub { [ 200, [], ['baz baby'] ] },
      ],

    client => sub {
        my $mech = shift;
        my $start_time = time;
        $mech->get_ok('/ambikon/xrefs/search?q=cromulence');
        diag $mech->content;
        $mech->content_contains( '"zee"',    'got xref response from subsite 1' );
        $mech->content_contains( 'baz baby', 'got xref response from subsite 2' );
    },
  );


done_testing;

