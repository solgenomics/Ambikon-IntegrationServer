package Ambikon::IntegrationServer::Postprocess::Text::MicroTemplate;
use Moose;

with 'Ambikon::IntegrationServer::Role::Postprocessor';

use Text::MicroTemplate ();

sub can_stream { 0 }

sub postprocess {
    my ( $self, $c ) = @_;

    $c->stash(
        subsite_postprocess_class  => ref $self,
        subsite_postprocess_object => $self,
      );

    $c->res->body( $self->_render( $c, $c->res->body ) );

    return 1;
}

sub _render {
    my ( $self, $c, $body ) = @_;

    return Text::MicroTemplate::render_mt(

        '? my ( $ambikon, $ambikon_text_mt ) = @_;'."\n"
        .$body,

        $c,
        $self,

     )->as_string
}


__PACKAGE__->meta->make_immutable;
1;

