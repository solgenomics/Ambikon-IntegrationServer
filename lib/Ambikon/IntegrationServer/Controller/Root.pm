package Ambikon::IntegrationServer::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

Ambikon::IntegrationServer::Controller::Root - Root Controller for Ambikon::IntegrationServer

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 default

Standard 404 error page

=cut

sub default :Private {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

sub end : Private {
    my ( $self, $c ) = @_;
    $c->forward('if_modified_since') unless $c->res->status == 304;
}

# check the if-modified-since header in the request vs the
# last-modified header in the response, and set a 304 if possible
sub if_modified_since : Private {
    my ( $self, $c ) = @_;

    if( my $since = $c->req->headers->if_modified_since ) {
        my $modtime = $c->res->headers->last_modified;
        if( $modtime && $modtime <= $since ) {
            $c->res->status(304); # http not modified
            $c->res->body(''); # and empty body
            $c->res->content_length(0);
            return 1;
        }
    }
    return 0;
}

=head1 AUTHOR

Robert Buels,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
