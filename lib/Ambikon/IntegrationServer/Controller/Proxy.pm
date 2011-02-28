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

        my $url     = $self->_build_internal_url( $c, $subsite );
        my $headers = $self->_build_internal_headers( $c, $subsite );

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
                if ($headers->{Status} !~ /^59\d+/) {
                    $c->res->status( $headers->{Status} );
                    $c->res->headers( HTTP::Headers->new( %$headers ) );
                }
                return 1;
            },
            on_body => sub { $c->res->write( $_[0] ); 1; },
            sub {
                my (undef, $headers) = @_;
                if (!$c->res->body and $headers->{Status} =~ /^59\d/) {
                    $c->res->status(502);
                    $c->res->content_type('text/html');
                    $c->res->body("Gateway error: $headers->{Reason}");
                }

                $cv->send;
            }
        );
        $cv->recv;
    }
}

sub _build_internal_url {
    my ( $self, $c, $subsite ) = @_;

    my $external_path = $subsite->external_path;
    my $external_pq   = $c->req->uri->path_query;

    my $internal_url_base  = $subsite->internal_url;
    ( my $internal_url = $external_pq ) =~ s/^$external_path/$internal_url_base/
        or die "cannot translate external path '$external_pq' for subsite ".$subsite->shortname;

    return $internal_url;
}

sub _build_internal_headers {
    my ( $self, $c, $subsite ) = @_;

    return +{ %{ $c->req->headers } };
}

__PACKAGE__->meta->make_immutable;
1;

