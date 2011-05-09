package Ambikon::IntegrationServer::SubsiteModifier::Text::MicroTemplate;
use Moose;

with 'Ambikon::IntegrationServer::Role::SubsiteModifier';

use Text::MicroTemplate ();

has 'arg_names' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [ 'ambikon', 'ambikon_postproc' ] },
    );

sub can_stream { 0 }

sub postprocess {
    my ( $self, $c ) = @_;

    $c->stash(
        subsite_postprocess_class  => ref $self,
        subsite_postprocess_object => $self,
      );

    $c->res->body( $self->render( $c->res->body ) );

    return 1;
}

sub render {
    my ( $self, $body ) = @_;

    my $code = Text::MicroTemplate->new({
        escape_func => undef,
        template    =>
            '? my ( '.join(', ', map '$'.$_, @{$self->arg_names || ['undef']} ).' ) = @_;'."\n"
            .$body,
       })->code;

    return (eval $code)->( $self->_app, $self );
}


__PACKAGE__->meta->make_immutable;
1;

