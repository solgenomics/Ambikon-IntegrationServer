package Ambikon::IntegrationServer::SubsiteModifier::TEDjs;
use Moose;

extends 'Ambikon::IntegrationServer::SubsiteModifier::RewriteURLs::HTML';

sub can_stream { 0 }

before modify_response => sub {
    my ( $self, $c ) = @_;

    return unless $c->req->uri =~ /menu\.js/;

    my $body = $c->res->body;

    $self->_rewrite_tag_attr( $c, \$body, @$_ )
        for
           [ a      => 'href'  ],
        ;

    $c->res->body( $body );
};

1;
