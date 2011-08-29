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
<subsite nonexistent>
 internal_url   http://$host:1/
 external_path  /nonexistent
</subsite>

    backends => [
        sub {
            my $env = shift;
            sleep rand(3);
            [ 200,
              [ 'Content-type' => 'application/json',
                'X-bar'  => 'fogbat',
                'X-zee'  => 'zaz',
              ],
              [ $json->encode({
                  xrefs => [ { text  => "twee",
                               url   => "zee",
                               "query" => "$env->{QUERY_STRING}",
                             },
                           ],
                })
              ]
            ];
        },

        sub { my $env = shift;
              [ 200,
                [],
                [ $json->encode({
                    xrefs => [
                               { text => 'hihi, and btw the query is '.$env->{QUERY_STRING},
                                 url  => 'noggin',
                               },
                             ],
                   })
                ],
              ]
            },

        sub { [ 404, [], ['Not found']] },
      ],

    client => sub {
        my $mech = shift;
        my $start_time = time;
        $mech->get_ok('/ambikon/xrefs/search_html?q=cromulence&q=monkeys');
        $mech->content_contains( 'twee', 'got xref response from subsite 1' );
        $mech->content_contains( 'href="zee"', 'got a link to zee from subsite 1' );
        $mech->content_contains( 'query is q=cromulence', 'see an xref for cromulence' );
        $mech->content_contains( 'query is q=monkeys', 'see an xref for monkeys' );
        $mech->content_lacks( 'Not found', 'got xref response from subsite 2' );
        $mech->content_lacks( "<$_ ", "does not have $_ opening tag" ) for qw( html body );

        #diag $mech->content;
    },
  );


done_testing;

