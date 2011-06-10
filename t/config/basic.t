use strict;
use warnings;
use Test::More;

use JSON::Any; my $j = JSON::Any->new;

BEGIN { $ENV{CATALYST_CONFIG_LOCAL_SUFFIX} = 'testing' }

use Catalyst::Test 'Ambikon::IntegrationServer';

my $subsites_r = request('/ambikon/subsite/list');
my $subsites_json = $subsites_r->content;
my $subsites = $j->from_json( $subsites_json );
#diag explain $subsites;
is( $subsites->{gbrowse}->{name}, 'GBrowse Development' );
is( $subsites->{gbrowse}->{alias}->[0], undef );
is( $subsites->{gbrowse}->{external_path}, '/gbrowse' );
is( $subsites->{gbrowse}->{internal_url}, 'http://localhost/gbrowse' );

done_testing;
