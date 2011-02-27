package App::Ambikon::IntegrationServer::Controller::Proxy;
use Moose;
use namespace::autoclean;

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

        #my $code = $self->_make_action_code_for( $subsite );
        my $code = sub {
            my ( $self, $c ) = @_;
            $c->res->body("proxied to ".$subsite->name);
        };

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

__PACKAGE__->meta->make_immutable;
1;

