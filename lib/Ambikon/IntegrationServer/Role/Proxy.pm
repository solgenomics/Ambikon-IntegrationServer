package Ambikon::IntegrationServer::Role::Proxy;
use Moose::Role;
use namespace::autoclean;

use HTTP::Headers ();
use HTTP::Request::Common ();
use URI ();

=method build_internal_req_body

figure out the body of the internal request

=cut

sub build_internal_req_body {
    my ( $self, $c, $subsite, $internal_headers ) = @_;

    my $type = $internal_headers->header('content-type')
        or return;

    if( $type =~ m!^application/x-www-form-urlencoded\b!i ) {
        my $u = URI->new;
        $u->query_form( $c->req->body_params );
        (my $body_string = "$u") =~ s/^\?//;
        $internal_headers->content_length( length $body_string );
        return $body_string;
    }
    elsif( $type =~ m!^multipart/form-data\b!i ) {
        # use a throwaway HTTP::Request obj to make the body (yuck).
        # upload-formatting code below is similar to
        # Catalyst::Controller::WrapCGI
        my $uploads = $c->req->uploads;
        my $post = HTTP::Request::Common::POST(
            'http://localhost/',
            'Content_Type' => 'form-data',
            Content => [
                %{ $c->req->body_params || {} },
                map {
                    my $u = $uploads->{$_};
                    $_ => [
                        undef,
                        $u->filename,
                        Content => $u->slurp,
                        map {
                            my $header = $_;
                            map { $header => $_ } $u->headers->header($header)
                        } $u->headers->header_field_names
                    ],
                }
                keys %$uploads
            ]
          );
        $internal_headers->header( 'Content-Type', $post->header('Content-Type') );
        $internal_headers->content_length( $post->headers->content_length );
        return $post->content;
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

    $headers = $headers->clone;
    my @header_names = $headers->header_field_names;
    $headers->remove_header(
        'Content-Length',
	'Accept-Encoding',
        'If-Modified-Since',
        ( grep /^X-Ambikon/i, @header_names ),
      );

    # add an X-Forwarded-For
    $headers->push_header( 'X-Forwarded-For', $c->req->hostname || $c->req->address );
    $headers->push_header( 'Via', $self->_via_str($c) );
    $headers->header( 'X-Ambikon', $c->version);

    return $headers;
}

=method build_external_res_headers

takes HTTP::Headers object, filters it and puts it into a new
HTTP::Headers object.

=cut

sub build_external_res_headers {
    my ( $self, $c, $subsite, $headers ) = @_;
    my $h = $headers->clone;

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
    $h->remove_header( $_ )
        for (
            qw(
                  URL
                  Reason
                  Transfer-Encoding
                  Server
                  HTTPVersion
                  Connection
                  TE
                  Trailer
              ),
            ( grep /^Client-/i, $h->header_field_names ),
            );

    $h->push_header( 'Via', $self->_via_str($c));
    $h->header( 'X-Ambikon', $c->version);

    return $h;
}

sub _via_str {
    my ( $self, $c ) = @_;

    my $u = $c->req->uri;
    return '1.1 '.$u->host.( $u->_port ? ':'.$u->_port : '' ).' (Ambikon/'.$c->version.')';
}


1;
