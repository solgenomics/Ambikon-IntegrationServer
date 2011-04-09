package Ambikon::IntegrationServer::Postprocess::Text::MicroTemplate;
use Moose;
use namespace::autoclean;

with 'Ambikon::IntegrationServer::Role::Postprocessor';

use Text::MicroTemplate 'render_mt';

sub can_stream { 0 }

sub postprocess {
    my ( $self, $c ) = @_;

    $c->stash(
        subsite_postprocess_class  => ref $self,
        subsite_postprocess_object => $self,
      );

    $c->res->body( $self->_render( $c->res->body ) );

    return 1;
}

sub _render {
    my ( $self, $body ) = @_;
    return render_mt(
        '? my ( $ambikon ) = @_;'."\n$body",
        $self,
     )->as_string
}


__PACKAGE__->meta->make_immutable;
1;

