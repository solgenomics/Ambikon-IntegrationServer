package Ambikon::IntegrationServer::SubsiteModifier::TEDjs;
use Moose;

extends 'Ambikon::IntegrationServer::SubsiteModifier::RewriteURLs::HTML';

sub can_stream { 0 }

around 'modify_response' => sub {
    my ( $orig, $self, $c ) = @_;

    return unless $c->req->uri =~ /menu\.js/;

    $self->$orig($c);
};

1;
