use strict;
use warnings;

use Test::More;
use Test::MockObject;

use aliased 'Ambikon::IntegrationServer::Postprocess::Text::MicroTemplate';

my $mock_c = Test::MockObject->new;
$mock_c->set_always('bar','foo');

is(
    MicroTemplate->new->render( $mock_c, 'Zee <?= $ambikon->bar ?>' ),
    'Zee foo',
    'microtemplate is templating, has $ambikon obj available',
    );

done_testing;
