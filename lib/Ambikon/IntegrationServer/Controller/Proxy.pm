package Ambikon::IntegrationServer::Controller::Proxy;
use Moose;
use namespace::autoclean;

use AnyEvent::HTTP;
use URI;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';
with 'Ambikon::IntegrationServer::Role::Proxy';

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

        my $url     = $self->build_internal_req_url( $c, $subsite, $c->req->uri );
        my $headers = $self->build_internal_req_headers( $c, $subsite, $c->req->headers );

        $c->log->debug( "Ambikon proxying to internal URL: $url" )
            if $c->debug;

        $c->stash(
            subsite      => $subsite,
            internal_url => ref $url ? $url : URI->new( $url ),
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
                }

                $cv->send;
            }
        );
        $cv->recv;
        if( defined $response_body_buffer && length $response_body_buffer ) {
            $c->res->body( $response_body_buffer );
            $_->postprocess( $c ) for $subsite->postprocessors_for( $c );
        }
    }
}

__PACKAGE__->meta->make_immutable;
1;

