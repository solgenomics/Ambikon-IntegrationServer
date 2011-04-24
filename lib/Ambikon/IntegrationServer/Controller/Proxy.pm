package Ambikon::IntegrationServer::Controller::Proxy;
use Moose;
use namespace::autoclean;

use AnyEvent::HTTP;
use URI;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

__PACKAGE__->config(
    'namespace' => '',
  );

# set up actions that proxy requests for each subsite.  overridden
# from base class Catalyst::Controller
sub register_actions {
    my ($self, $app) = @_;
    my $class = ref $self || $self;

    my $namespace = $self->action_namespace($app);

    for my $subsite ( values %{$app->subsites} ) {

        my $action_name = 'subsite_'.$subsite->shortname;
        my $reverse     = $namespace ? "$namespace/$action_name" : $action_name;

        my $code = $self->make_action_code( $subsite );

        my $action = $self->create_action(
            'name'       => $action_name,
            'code'       => $code,
            'reverse'    => $reverse,
            'namespace'  => $namespace,
            'class'      => $class,
            'attributes' => {
                'Path' => [ $subsite->external_path ],
            },
          );

        $app->dispatcher->register($app, $action);
    }
}

=method make_action_code

makes and returns the actual subroutine for the proxy action for a
subsite.  Implementation using AnyEvent::HTTP.

=cut

sub make_action_code {
    my ( undef, $subsite ) = @_;

    # the below is inspired heavily by Plack::App::Proxy
    return sub {
        my ( $self, $c ) = @_;

        my $url     = $self->build_internal_req_url( $c, $subsite );
        my $headers = $self->build_internal_req_headers( $c, $subsite );

        $c->log->debug( "Ambikon proxying to internal URL: $url" )
            if $c->debug;

        $c->stash(
            subsite      => $subsite,
            internal_url => $url,
            );

        my $method  = uc $c->req->method;

        my $body    = $self->build_internal_req_body( $c, $subsite, $headers );

        my $cv = AnyEvent->condvar;
        my $should_stream;
        my $response_body_buffer = ''; #< only used if non-streaming
        my $req = AnyEvent::HTTP::http_request(
            $method    => $url,
            headers    => $headers,
            body       => $body,
            recurse    => 0,  # want not to treat any redirections
            persistent => 1,
            proxy      => undef, # $ENV{http_proxy} causing test failures
            on_header  => sub {
                my $headers = shift;
                if ( $headers->{Status} !~ /^59\d+/ ) {
                    $c->res->status( $headers->{Status} );
                    $c->res->headers( $self->build_external_res_headers( $c, $subsite, $headers ));
                }
                return 1;
            },
            on_body => sub {
                # we decide whether we are going to stream *when the
                # body begins*, so that we can use the headers in our
                # decision
                unless( defined $should_stream ) {
                    $should_stream = $subsite->should_stream( $c );
                    $c->log->debug("request streaming: ".($should_stream ? 'YES' : 'NO')) if $c->debug;
                }

                if( $should_stream ) {
                    $c->res->write( $_[0] );
                } else {
                    $response_body_buffer .= $_[0];
                }

                return 1;
            },
            sub {
                my ($data, $headers) = @_;
                if ( $headers->{Status} =~ /^59\d/ ) {
                    $c->res->status(502);
                    $c->res->content_type('text/html');
                    $c->res->body("Gateway error: $headers->{Reason}");

                } else {
                    $response_body_buffer ||= $data;
                    if( defined $response_body_buffer && length $response_body_buffer ) {
                        $c->res->body( $response_body_buffer );
                        $_->postprocess( $c ) for $subsite->postprocessors_for( $c );
                    }
                }

                $cv->send;
            }
        );
        $cv->recv;
    }
}


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
    my ( $self, $c, $subsite ) = @_;

    my $external_path = $subsite->external_path;
    my $external_pq   = $c->req->uri->path_query;

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
    my ( $self, $c, $subsite ) = @_;

    my %h = %{ $c->req->headers };
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

    $h->header( URL => undef ); #< remove any URL header, this leaks
                                #what the internal server is

    return $h;
}

__PACKAGE__->meta->make_immutable;
1;

