package Ambikon::IntegrationServer::Controller::Proxy;
use Moose;
use namespace::autoclean;

use AnyEvent::HTTP;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

__PACKAGE__->config(
    'namespace' => '',
  );

# set up actions that proxy requests for each subsite
sub register_actions {
    my ($self, $app) = @_;
    my $class = ref $self || $self;

    my $namespace = $self->action_namespace($app);

    for my $subsite ( values %{$app->subsites} ) {

        my $action_name = 'subsite_'.$subsite->shortname;
        my $reverse     = $namespace ? "$namespace/$action_name" : $action_name;

        my $code = $self->_make_action_code_ae( $subsite );

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

# makes and returns the actual subroutine for the proxy action for a
# subsite.  Implementation using AnyEvent::HTTP.
sub _make_action_code_ae {
    my ( undef, $subsite ) = @_;

    # the below is based heavily on Plack::App::Proxy
    return sub {
        my ( $self, $c ) = @_;

        my $url     = $self->_build_internal_req_url( $c, $subsite );
        my $headers = $self->_build_internal_req_headers( $c, $subsite );

        $c->log->debug( "Ambikon proxying to internal URL: $url" )
            if $c->debug;

        my $method  = uc $c->req->method;
        # TODO: figure out the body properly
        my $body    = $c->req->body || undef;

        my $cv = AnyEvent->condvar;
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
                    $c->res->headers( $self->_build_external_res_headers( $headers ));
                }
                return 1;
            },
            on_body => sub { $c->res->write( $_[0] ); 1; },
            sub {
                my ($data, $headers) = @_;
                if ( $headers->{Status} =~ /^59\d/ ) {
                    $c->res->status(502);
                    $c->res->content_type('text/html');
                    $c->res->body("Gateway error: $headers->{Reason}");
                }

                $c->res->body( $data ) if defined $data;

                $cv->send;
            }
        );
        $cv->recv;
    }
}

# figure out the internal URL that handles a given client request
sub _build_internal_req_url {
    my ( $self, $c, $subsite ) = @_;

    my $external_path = $subsite->external_path;
    my $external_pq   = $c->req->uri->path_query;

    my $internal_url_base  = $subsite->internal_url;
    ( my $internal_url = $external_pq ) =~ s/^$external_path/$internal_url_base/
        or die "cannot translate external path '$external_pq' for subsite ".$subsite->shortname;

    return $internal_url;
}

# makes a bare hashref of headers for the internal request, using the
# user's request headers
sub _build_internal_req_headers {
    my ( $self, $c, $subsite ) = @_;

    my %h = %{ $c->req->headers };
    for (keys %h) {
        delete $h{$_} if /^X-Ambikon-/i;
    }

    return \%h;
}

# takes headers bare hashref, filters it and puts it into an
# HTTP::Headers object.
sub _build_external_res_headers {
    my ( $self, $headers ) = @_;
    my %h = %$headers;
    return HTTP::Headers->new( %h );
}

__PACKAGE__->meta->make_immutable;
1;

