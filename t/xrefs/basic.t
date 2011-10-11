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
  tags foobartag!
</subsite>
<subsite baz>
 internal_url   http://$host:$port2/
 external_path  /fog
</subsite>
<subsite nosupport>
 internal_url   http://$host:$port3/
 external_path  /nosupport
</subsite>
<subsite excluded_test>
 internal_url   http://$host:$port4
 external_path  /excl
 tags  exclude_me_please
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
              [ qq|{ "xrefs" : [{ "twee": "zee", "query": "$env->{QUERY_STRING}", "tags": ["hihi"] }] }| ],
            ];
        },

        sub { [ 200, [], ['baz baby'] ] },

        sub { [ 404, [], ['Not found']] },

        sub {
            my $env = shift;
            [ 200,
              [],
              [
                qq|{ "xrefs" : [{ "url":"uh-oh", "text": "this should be excluded!", "query": "$env->{QUERY_STRING}" }] }|
              ]
            ]
        },
      ],

    client => sub {
        my $mech = shift;
        my $start_time = time;
        $mech->get_ok('/ambikon/xrefs/search?q=cromulence&q=monkeys&subsites_without_tag=exclude_me_please');
        $mech->content_contains( '"zee"',    'got xref response from subsite 1' );
        $mech->content_contains( 'baz baby', 'got xref response from subsite 2' );

        my $data = $json->decode( $mech->content );

        is ref $data, 'HASH', 'aggregated response decoded ok';
        ok $data->{cromulence}{baz}{error_message},
           'got an error from the baz subsite, because of its malformed response';
        is $data->{cromulence}{foo_bar}{http_status}, 200,
           'foo_bar subsite response is OK';
        is $data->{monkeys}{foo_bar}{http_status}, 200;
        is $data->{cromulence}{foo_bar}{xref_set}{xrefs}[0]{tags}[1], 'foobartag!';
        is $data->{monkeys}{foo_bar}{xref_set}{xrefs}[0]{tags}[1], 'foobartag!';

        ok !exists $data->{cromulence}{excluded_test}, 'excluded subsite not there';

        ok !exists $data->{cromulence}{nosupport},
            '404 response from nosupport subsite, so not included in results';
        ok !exists $data->{cromulence}{nonexistent},
            'nonexistent site is down, so not included in xrefs';


        $mech->get_ok( '/ambikon/xrefs/search?q=noggin&subsites_with_tag=Foobartag!' );
        $data = $json->decode( $mech->content );

        is scalar( values %{$data->{noggin}} ), 1, 'only 1 subsite matches foobartag!';
        is scalar( @{$data->{noggin}{foo_bar}{xref_set}{xrefs}}), 1, 'got 1 xref from foo_bar subsite';

        $mech->get_ok( '/ambikon/xrefs/search?q=noggin&subsites_with_tag=foobartag!&format=flat_array' );
        $data = $json->decode( $mech->content );
        is ref $data, 'ARRAY', 'data is an arrayref with flat_array format argument';
        is $data->[0]{tags}[1], 'foobartag!', 'got the right tag for the first xref';

        $mech->get_ok( '/ambikon/xrefs/search?q=noggin&q=ziggy&subsites_with_tag=unsatisfiable!' );
        $data = $json->decode( $mech->content );
        is_deeply( $data, { noggin => {}, ziggy => {} }, 'got right response for no subsites' );

        $mech->get_ok( '/ambikon/xrefs/search?q=noggin&q=ziggy&subsites_with_tag=foobartag!&xrefs_with_tag=nonexistent' );
        $data = $json->decode( $mech->content );

        is( scalar @{$data->{noggin}{foo_bar}{xref_set}{xrefs}}, 0, 'no xrefs satisfy');

        $mech->get_ok( '/ambikon/xrefs/search?q=noggin&q=ziggy&subsites_with_tag=foobartag!&xrefs_with_tag=hihi' );
        $data = $json->decode( $mech->content );

        is( scalar @{$data->{noggin}{foo_bar}{xref_set}{xrefs}}, 1, 'one xref satisfies');
    },
  );


done_testing;

