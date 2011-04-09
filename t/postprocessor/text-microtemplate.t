use strict;
use warnings;

use Test::More;

use aliased 'Ambikon::IntegrationServer::Postprocess::Text::MicroTemplate';

is( MicroTemplate->_render( 'Zee <?= $ambikon->can_stream ?>' ), 'Zee 0' );

done_testing;
