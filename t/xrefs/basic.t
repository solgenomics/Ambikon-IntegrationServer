use strict;
use warnings;

use Test::More;
use IO::String;

use JSON::Any; my $json = JSON::Any->new;

use lib 't/lib';
use Ambikon::IntegrationServer::Test::Constellation qw/ test_constellation filter_env /;

test_constellation(
    conf => <<'',
<subsite foo_bar>
  internal_url   http://$host:$port/monkeys
  external_path  /foo
</subsite>
<subsite baz>
 internal_url   http://$host:$port2/
 external_path  /fog
</subsite>
<subsite nosupport>
 internal_url   http://$host:$port3/
 external_path  /nosupport
</subsite>
<subsite nonexistent>
 internal_url   http://$host:1/
 external_path  /nonexistent
</subsite>

    backends => [
        sub {
            my $env = shift;
            sleep rand(3);
            [ 200,
              [ 'Content-type' => 'text/html',
                'X-bar'  => 'fogbat',
                'X-zee'  => 'zaz',
              ],
              [ qq|[{ "twee": "zee", "query": "$env->{QUERY_STRING}" }]| ],
            ];
        },

        sub { [ 200, [], ['baz baby'] ] },

        sub { [ 404, [], ['Not found']] },
      ],

    client => sub {
        my $mech = shift;
        my $start_time = time;
        $mech->get_ok('/ambikon/xrefs/search?q=cromulence&q=monkeys');
        $mech->content_contains( '"zee"',    'got xref response from subsite 1' );
        $mech->content_contains( 'baz baby', 'got xref response from subsite 2' );

        my $data = $json->decode( $mech->content );

        is ref $data, 'HASH', 'aggregated response decoded ok';
        ok $data->{cromulence}{baz}{error_message},
           'got an error from the baz subsite, because of its malformed response';
        is $data->{cromulence}{foo_bar}{http_status}, 200,
           'foo_bar subsite response is OK';

        ok !exists $data->{cromulence}{nosupport},
            '404 response from nosupport subsite, so not included in results';
        ok !exists $data->{cromulence}{nonexistent},
            'nonexistent site is down, so not included in xrefs';


    },
  );


done_testing;

