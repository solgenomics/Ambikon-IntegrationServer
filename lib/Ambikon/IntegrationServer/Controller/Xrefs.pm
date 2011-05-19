package Ambikon::IntegrationServer::Controller::Xrefs;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    namespace => '/ambikon/xrefs'
    );


sub aggregate_xrefs : Path('/ambikon/xrefs') ActionClass('REST') {}

sub aggregate_xrefs_POST : Args(0) {
    my ( $self, $c ) = @_;

    # proxy it out in parallel to all the subsites that are registered
    # as providing xrefs
    


    # aggregate the results and return them

}



1;
