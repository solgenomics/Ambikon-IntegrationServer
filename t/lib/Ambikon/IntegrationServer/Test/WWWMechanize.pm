package #hide from PAUSE
    Ambikon::IntegrationServer::Test::WWWMechanize;
use Moose;

extends 'Test::WWW::Mechanize::Catalyst';

has '+catalyst_app', ( default => 'Ambikon::IntegrationServer' );

1;
