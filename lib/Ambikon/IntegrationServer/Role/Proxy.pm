package Ambikon::IntegrationServer::Role::Proxy;
use Moose::Role;
use namespace::autoclean;

use HTTP::Headers ();
use URI ();

=method build_internal_req_body

figure out the body of the internal request

=cut

sub build_internal_req_body {
    my ( $self, $c, $subsite, $internal_headers ) = @_;

    my $type = $internal_headers->{'content-type'}
        or return;

    if( $type =~ m!^application/x-www-form-urlencoded\b!i ) {
        my $u = URI->new;
        $u->query_form( $c->req->body_params );
        (my $body_string = "$u") =~ s/^\?//;
        return $body_string;
    }
    elsif( $type =~ m!^multipart/form-data\b!i ) {
        die 'multipart/form-data not yet handled';
    }

    return;
}

=method build_internal_req_url

figure out the internal URL that handles a given client request

=cut

sub build_internal_req_url {
    my ( $self, $c, $subsite, $url ) = @_;

    my $external_path = $subsite->external_path;
    my $external_pq   = $url->path_query;

    my $internal_url_base  = $subsite->internal_url;
    ( my $internal_url = $external_pq ) =~ s/^$external_path/$internal_url_base/
        or die "cannot translate external path '$external_pq' for subsite ".$subsite->shortname;

    return $internal_url;
}

=method build_internal_req_headers

makes a bare hashref of headers for the internal request, using the
user's request headers

=cut

sub build_internal_req_headers {
    my ( $self, $c, $subsite, $headers ) = @_;

    my %h = %$headers;
    for (keys %h) {
        delete $h{$_} if /^X-Ambikon-/i;
    }

    return \%h;
}

=method build_external_res_headers

takes headers bare hashref, filters it and puts it into an
HTTP::Headers object.

=cut

sub build_external_res_headers {
    my ( $self, $c, $subsite, $headers ) = @_;
    my $h = HTTP::Headers->new(  %$headers );

    # trim off the internal host from a Location
    if( my $l = $h->header( 'Location' ) ) {
        $l = URI->new( $l )->canonical;
        my $internal_host = $subsite->internal_url->clone->canonical;
        $internal_host->path_query( '' );
        if( $l =~ s/^$internal_host// ) {
            $h->header('Location' => $l );
        }
    }

    # remove some headers
    $h->remove_header( $_ ) for qw( URL Reason Transfer-Encoding Server HTTPVersion Connection );

    return $h;
}


1;
