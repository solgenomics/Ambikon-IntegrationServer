package Ambikon::IntegrationServer::Controller::Proxy;
use Moose;
use namespace::autoclean;

use AnyEvent::HTTP;

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
        # TODO: figure out the body properly
        my $body    = $c->req->body || undef;

        my $cv = AnyEvent->condvar;
        my $should_stream;
        my $body_buffer = ''; #< only used if non-streaming
        my $req = AnyEvent::HTTP::http_request(
            $method    => $url,
            headers    => $headers,
            body       => $body,
            recurse    => 0,  # want not to treat any redirections
            persistent => 0,
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
                    $body_buffer .= $_[0];
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
                    $body_buffer ||= $data;
                    if( defined $body_buffer && length $body_buffer ) {
                        $c->res->body( $body_buffer );
                        $_->postprocess( $c ) for $subsite->postprocessors_for( $c );
                    }
                }

                $cv->send;
            }
        );
        $cv->recv;
    }
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
    my %h = %$headers;
    return HTTP::Headers->new( %h );
}

__PACKAGE__->meta->make_immutable;
1;

