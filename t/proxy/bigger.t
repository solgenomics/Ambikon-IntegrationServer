use strict;
use warnings;

use Test::More;

use Data::Dump;

use lib 't/lib';
use Ambikon::IntegrationServer::Test::Proxy 'test_proxy';


# bigger test with 3 backends
test_proxy(
    conf => <<'EOC',
<subsite dum>
  name Tweedle Dum
  internal_url  http://$host:$port1/zoz
  external_path  /sub/dum
</subsite>
<subsite dee>
  name Tweedle Dee
  internal_url  http://$host:$port2/zonk
  external_path /sub/dee
</subsite>
<subsite the_other_one>
  name The Other One!
  internal_url http://$host:$port3
  external_path /other
</subsite>
EOC

    backends => [
        sub { [ 200, [], ["Tweedle dum, with request URI ".shift->{REQUEST_URI}  ] ] },
        sub { [ 404, [], ['Tweedle dee has no pages!'                            ] ] },
        sub { [ 500, [], ['And the other one always crashes!'                    ] ] },
      ],

    client => sub {
        my $mech = shift;
        $mech->get_ok('/sub/dum/foggin/noggin');
        $mech->content_contains('Tweedle dum');
        $mech->content_contains('foggin/noggin');

        $mech->get('/sub/dee/nothing/here');
        is $mech->status, 404, 'Got a 404 from tweedle dee';
        $mech->content_contains( 'no pages!' );

        $mech->get( '/other' );
        is $mech->status, 500, 'other gave a 500';
        $mech->content_contains('always crashes');
    },
);


done_testing;
