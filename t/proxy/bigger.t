use strict;
use warnings;

use Test::More;

use JSON::Any; my $json = JSON::Any->new;

use lib 't/lib';
use Ambikon::IntegrationServer::Test::Proxy qw/ test_proxy  filter_env /;


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
<subsite the_root>
  name Subsite at the Root!
  # the root also has a path-less internal_url
  internal_url http://$host:$port4
  external_path /
</subsite>
EOC

    backends => [
        sub { [ 200, [], [ $json->encode( filter_env( { %{+shift}, hi => 'Tweedle dum here' }))]]},
        sub { [ 404, [], ['Tweedle dee has no pages!'                                          ]]},
        sub { [ 500, [], ['And the other one always crashes!'                                  ]]},
        sub { [ 200, [], ['This is the root backend'                                           ]]},
      ],

    client => sub {
        my $mech = shift;
        $mech->add_header( 'X-Ambikon-User' => 'badman' );
        $mech->get_ok('/sub/dum/foggin/noggin');
        $mech->content_contains('Tweedle dum');
        $mech->content_contains('foggin/noggin');
        my $dum_env = $json->decode( $mech->content );
        is ref $dum_env, 'HASH', 'decoded env';
        isnt $dum_env->{HTTP_X_AMBIKON_USER}, 'badman', 'user requests cannot set X-Ambikon-User';

        $mech->get('/sub/dee/nothing/here');
        is $mech->status, 404, 'Got a 404 from tweedle dee';
        $mech->content_contains( 'no pages!' );

        $mech->get( '/other' );
        is $mech->status, 500, 'other gave a 500';
        $mech->content_contains('always crashes');

        # check that a pathless internal_url works
        $mech->get_ok( '/fooey' );
        $mech->content_contains('root backend', 'pathless internal url sems to work');
    },
);


done_testing;
