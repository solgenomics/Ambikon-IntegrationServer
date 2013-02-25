package Ambikon::IntegrationServer::Role::Proxy;
use Moose::Role;
use namespace::autoclean;

use Scalar::Util ();

use HTTP::Headers ();
use HTTP::Request::Common ();
use URI ();

=method build_internal_req_body( $c, $subsite, $internal_headers )

figure out the body of the internal request

=cut

sub build_internal_req_body {
    my ( $self, $c, $subsite, $internal_headers ) = @_;

    my $type = $internal_headers->header('content-type')
        or return;

    if( my $body = $c->req->body ) {
        # just slurp the whole body if present
        local $/;
        return scalar <$body>;
    }
    elsif( $type =~ m!^application/x-www-form-urlencoded\b!i ) {
        my $u = URI->new;
        $u->query_form( $c->req->body_params );
        my $body_string = $u->query;
        if( defined $body_string ) {
            $internal_headers->content_length( length $body_string );
        }
        return $body_string;
    }
    elsif( $type =~ m!^multipart/form-data\b!i ) {
        # use a throwaway HTTP::Request obj to make the body (yuck).
        # upload-formatting code below is similar to
        # Catalyst::Controller::WrapCGI

        # for HTTP::Request::Common, need to expand multi-valued body
        # params, e.g. ( foo => [1,2] ) into ( foo => 1, foo => 2 )
        my $body_params = $c->req->body_params;
        my @body_params = map {
            my $key = $_;
            my $val = $body_params->{$_};
            if( ref $val && ref $val eq 'ARRAY' ) {
                map { $key => $_ } @$val
            } else {
                $key => $val
            }
        } keys %$body_params;

        local $HTTP::Request::Common::DYNAMIC_FILE_UPLOAD = 1;
        my $uploads = $c->req->uploads;
        my $post = HTTP::Request::Common::POST(
            'http://localhost/',
            'Content_Type' => 'form-data',
            Content => [
                @body_params,
                map {
                    my $u = $uploads->{$_};
                    $_ => [
                        $u->tempname,
                        $u->filename,
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
    $external_path = '' if ! defined $external_path || $external_path eq '/';
    my $external_pq   = $url->path_query;

    my $internal_url_base  = $subsite->internal_url;
    ( my $internal_url = $external_pq ) =~ s/^$external_path/$internal_url_base/
        or die "cannot translate external path '$external_pq' for subsite ".$subsite->shortname;

    return $internal_url;
}

=method build_internal_req_headers

makes an HTTP::Headers object of headers for the internal request,
using the user's request headers

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

    # add a Via header listing this server, and check for request
    # cycles while doing so
    my $via = $self->_via_str( $c );
    if( my $existing_via = $headers->header( 'Via' ) ) {
        index( $existing_via, $via ) == -1
            or die "Cycle of Ambikon self-requests detected for URL ".$c->req->uri.".  Please check the integration server configuration for incorrect internal URLs.\n";
    }
    $headers->push_header( 'Via', $via );

    $headers->header( 'X-Ambikon-Version', $c->version );
    $headers->header( 'X-Ambikon-Server-Url', 'http://'.$self->ambikon_host_and_port($c).'/ambikon' );

    return $headers;
}

=method headers_hashref( $headers )

Converts an HTTP::Headers object into a bare hashref.

=cut

sub bare_headers_hashref {
    my ( $self, $headers ) = @_;

    if( Scalar::Util::blessed( $headers ) ) {
        my %h;
        for my $name ( $headers->header_field_names ) {
            $h{$name} = $headers->header( $name );
        }
        return \%h;
    }
    else {
        return $headers;
    }
}

=method build_external_res_headers

takes HTTP::Headers object, filters it and returns a new
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
                  Vary
              ),
            ( grep /^Client-/i, $h->header_field_names ),
            );

    $h->push_header( 'Via', $self->_via_str($c ) );
    $h->header( 'X-Ambikon-Version', $c->version);

    return $h;
}

sub _via_str {
    my ( $self, $c ) = @_;

    return '1.1 '.$self->ambikon_host_and_port($c).' ('.$c->version_string.')';
}

sub ambikon_host_and_port {
    my ( $self, $c ) = @_;

    my $u = $c->req->uri;
    my $host = $u->host;
    my $port = $u->_port;

    return wantarray
        ? ( $host, $port )
        : $host.( $port ? ':'.$port : '' );
}


1;
