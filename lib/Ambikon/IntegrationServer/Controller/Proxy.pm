package Ambikon::IntegrationServer::Controller::Proxy;
use Moose;
use namespace::autoclean;

use HTTP::Request;
use LWP::UserAgent;
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
subsite.

=cut

sub make_action_code {
    my ( undef, $subsite ) = @_;

    # the below is inspired heavily by Plack::App::Proxy
    return sub {
        my ( $self, $c ) = @_;

        $c->stash->{subsite} = $subsite;

        my $req = do {
            my $method  = uc $c->req->method;
            my $url     = $self->build_internal_req_url( $c, $subsite, $c->req->uri );
            my $headers = $self->build_internal_req_headers( $c, $subsite, $c->req->headers );
            my $body    = $self->build_internal_req_body( $c, $subsite, $headers );
            HTTP::Request->new( $method, $url, [ %{ $self->bare_headers_hashref( $headers ) } ], $body );
        };

        @{$c->stash}{'internal_request','internal_url'} = ( $req, $req->uri );

        $c->log->debug( "Ambikon proxying to internal URL: ".$req->uri )
            if $c->debug;

        $_->modify_request( $c, $req ) for $subsite->modifiers_for( $c );

        my $streaming_this_request;
        my $response_body_buffer = ''; #< only used if non-streaming

        my $ua = LWP::UserAgent->new;
        $ua->max_redirect(0);
        $ua->proxy(['http','ftp'],'');

        $ua->add_handler(
            response_header => sub {
                my ( $res ) = @_;
                if ( $res->code !~ /^59\d+/ ) {
                    $c->res->status( $res->code );
                    $c->res->headers( $self->build_external_res_headers( $c, $subsite, $res->headers ));
                }
                $res->{default_add_content} = 0;
                $streaming_this_request = $self->_decide_whether_to_stream( $c, $subsite );
                $c->log->debug("request streaming: ".($streaming_this_request ? 'YES' : 'NO')) if $c->debug;
                return 1;
            });

        $ua->add_handler(
            response_data => sub {
                my (undef, undef, undef, $data) = @_;

                if( $streaming_this_request ) {
                    $c->res->write( $data );
                } else {
                    $response_body_buffer .= $data;
                }

                return 1;
            });

        my $res = $ua->simple_request( $req );

        if ( $res->code =~ /^59\d/ ) {
            $c->res->status(502);
            $c->res->content_type('text/html');
            $c->res->body("Gateway error: ".$res->header('Reason'));
        } else {
            if( defined $response_body_buffer && length $response_body_buffer ) {
                $c->res->body( $response_body_buffer );
            }
        }

        $_->modify_response( $c ) for $subsite->modifiers_for( $c );
    }
}


sub _decide_whether_to_stream {
    my ( $self, $c, $subsite ) = @_;
    return 0 unless $subsite->can_stream( $c );
    my $content_length = $c->res->content_length;
    return 1 unless defined $content_length;
    return 0 if $content_length < 500_000;
    return 1;
}

__PACKAGE__->meta->make_immutable;
1;

