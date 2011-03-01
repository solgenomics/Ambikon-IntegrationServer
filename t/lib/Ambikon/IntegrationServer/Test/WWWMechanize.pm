package #hide from PAUSE
    Ambikon::IntegrationServer::Test::WWWMechanize;
use strict;
use warnings;

use File::Temp;

use parent 'Test::WWW::Mechanize::Catalyst';

sub new {
    my ( $class, %args ) = @_;

    local $ENV{CATALYST_CONFIG} = $ENV{CATALYST_CONFIG};
    local $ENV{CATALYST_SERVER} = $ENV{CATALYST_SERVER};

    my $temp_conf;
    if ( my $conf_text = delete $args{configuration} ) {
        $temp_conf = File::Temp->new( SUFFIX => '.conf' );
        $temp_conf->print( $conf_text );
        $temp_conf->close;
        $ENV{CATALYST_CONFIG} = $temp_conf->filename;
        delete $ENV{CATALYST_SERVER};
    }

    return $class->SUPER::new(
        catalyst_app => 'Ambikon::IntegrationServer',
        %args,
      );
}

1;
