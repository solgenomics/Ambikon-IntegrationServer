package Ambikon::IntegrationServer::Role::Postprocessor;
use Moose::Role;

sub will_postprocess { 1 }

requires 'postprocess', 'can_stream';


1;
