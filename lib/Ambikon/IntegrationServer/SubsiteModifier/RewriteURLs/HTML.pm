package Ambikon::IntegrationServer::SubsiteModifier::RewriteURLs::HTML;
use Moose;

with 'Ambikon::IntegrationServer::Role::SubsiteModifier';
with 'Ambikon::IntegrationServer::Role::URLRewriter';

sub can_stream { 0 }

sub modify_response {
    my ( $self, $c ) = @_;

    my $body = $c->res->body;

    $self->_rewrite_tag_attr( $c, \$body, @$_ )
        for
           [ a      => 'href'  ],
           [ img    => 'src'   ],
           [ script => 'src'   ],
           [ link   => 'href'  ],
       ;

    $c->res->body( $body );
}
sub _rewrite_tag_attr {
    my ( $self, $c, $bref, $tag, $attrname ) = @_;
    $$bref =~ s/(< \s* $tag \s+ [^>]* $attrname \s* = \s* ["']?)([^"'\s>]+)/$1.$self->rewrite_url_internal_to_external($c,$2)/esgix;
}

__PACKAGE__->meta->make_immutable;
1;
