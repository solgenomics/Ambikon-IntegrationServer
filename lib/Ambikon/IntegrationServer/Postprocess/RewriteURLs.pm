package Ambikon::IntegrationServer::Postprocess::RewriteURLs;
use Moose;

with 'Ambikon::IntegrationServer::Role::Postprocessor';

sub can_stream { 0 }

sub postprocess {
    my ( $self, $c ) = @_;



}

sub rewrite_url {
    my ( $self, $c, $url ) = @_;
    $url = URI->new( $url ) unless ref $url;

    my $internal_root = $self->_subsite->internal_url->canonical;
    my $external_path = $self->_subsite->external_path;
    my $ext_request   = $c->req->uri;
    my $int_request   = $c->stash->{internal_url};

    # make it absolute if not already
    my $abs = $url->abs( $int_request )->canonical;

    # reroot it
    (my $new_url = $abs) =~ s/^$internal_root/$external_path/;
    $new_url = URI->new( $new_url );

    # and now relativize it again
    $url = $new_url->rel( $ext_request );

    return $url;
}

__PACKAGE__->meta->make_immutable;
1;
