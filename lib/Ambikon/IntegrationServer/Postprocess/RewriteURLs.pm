package Ambikon::IntegrationServer::Postprocess::RewriteURLs;
use Moose;

with 'Ambikon::IntegrationServer::Role::Postprocessor';

sub can_stream { 0 }

sub postprocess {
    my ( $self, $c ) = @_;

    my $body = $c->res->body;

    $self->_rewrite_tag_attr( $c, \$body, @$_ )
        for [qw[ a href ]], [qw[ img src ]];

    $c->res->body( $body );
}
sub _rewrite_tag_attr {
    my ( $self, $c, $bref, $tag, $attrname ) = @_;
    $$bref =~ s/(< \s* $tag \s+ [^>]* $attrname \s* = \s* ["']?)([^"'\s>]+)/$1.$self->rewrite_url($c,$2)/esgix;
}


sub rewrite_url {
    my ( $self, $c, $url ) = @_;

    # don't rewrite empty URLs
    return $url unless defined $url && length $url;

    # coerce to URI object if necessary
    $url = URI->new( $url ) unless ref $url;

    # these are the environment we're operating in
    my $internal_root = $self->_subsite->internal_url->canonical;
    my $external_path = $self->_subsite->external_path;
    my $ext_request   = $c->req->uri;
    my $int_request   = $c->stash->{internal_url};

    # if we have a URL that's the same host, but a different scheme,
    # convert the URL to an absolute one with out host for the
    # purposes of the rest of the conversion, and then add the scheme
    # and host back in at the end
    my $force_ext_scheme;
    if(    $url->can('scheme')
        && $url->scheme
        && $url->scheme =~ /^http/
        && $url->can('host')
        && $url->host eq $int_request->host
        && $url->scheme ne $int_request->scheme
      ) {
        $force_ext_scheme = $url->scheme;
        $url = URI->new( $url->path_query.( defined $url->fragment ? '#'.$url->fragment : '' ));
    }

    ### make it absolute if not already
    my $abs = $url->abs( $int_request )->canonical;

    ### reroot it
    s!/+$!! for $internal_root, $external_path;
    #warn "$abs =~ s!^$internal_root!$external_path!\n";
    (my $new_url = $abs) =~ s/^$internal_root/$external_path/
      or return $url;
    $new_url = URI->new( $new_url );

    ### and now relativize it again
    $url = $new_url->rel( $ext_request );

    # rebuild the URL if we have to force the scheme used for the
    # remapped URL
    if( $force_ext_scheme ) {
        $url = URI->new( $force_ext_scheme.'://'.$ext_request->host.$url->path_query.( defined $url->fragment ? '#'.$url->fragment : '' ));
    }

    return $url;
}

# more complex rewriting method that can handle differing 
sub rewrite_url_abs {

}

__PACKAGE__->meta->make_immutable;
1;
