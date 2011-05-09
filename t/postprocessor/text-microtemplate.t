use strict;
use warnings;

use Test::More;
use Test::MockObject;

use aliased 'Ambikon::IntegrationServer::SubsiteModifier::Text::MicroTemplate';

my $mock_c = Test::MockObject->new;
$mock_c->set_isa('Ambikon::IntegrationServer');
$mock_c->set_always('bar','foo');

my $mock_ss = Test::MockObject->new;
$mock_ss->set_isa('Ambikon::IntegrationServer::Subsite');

is(
    MicroTemplate->new( _app => $mock_c, _subsite => $mock_ss )->render( 'Zee <?= $ambikon->bar ?>' ),
    'Zee foo',
    'microtemplate is templating, has $ambikon obj available',
    );

done_testing;
