use strict;
use warnings;
use Test::More;

use JSON::Any; my $j = JSON::Any->new;

BEGIN { $ENV{CATALYST_CONFIG_LOCAL_SUFFIX} = 'testing' }

use lib 't/lib';
use aliased 'Ambikon::IntegrationServer::Test::WWWMechanize';

my $mech = WWWMechanize->new;
$mech->get_ok('/ambikon/subsite/list');

my $subsites_json = $mech->content;
my $subsites = $j->from_json( $subsites_json );
#diag explain $subsites;
is( $subsites->{gbrowse}->{name}, 'GBrowse Development' );
is( $subsites->{gbrowse}->{alias}->[0], undef );
is( $subsites->{gbrowse}->{external_path}, '/gbrowse' );
is( $subsites->{gbrowse}->{internal_url}, 'http://localhost/gbrowse' );

done_testing;
