package Ambikon::IntegrationServer::SubsiteModifier::Theme::ForcibleTemplate;
use Moose;
use namespace::autoclean;

extends 'Ambikon::IntegrationServer::SubsiteModifier::Text::MicroTemplate';

# endows this postprocessor with fetch_theme, head, body_start, and
# body_end methods
with(qw(
           Ambikon::IntegrationServer::Role::SubsiteModifier
           Ambikon::IntegrationServer::Role::Proxy
           Ambikon::IntegrationServer::Role::TemplateTheme
       ));

# need to fetch the theme template before each render
before 'modify_response' => sub {
    my ( $self, $c ) = @_;

    $self->fetch_theme( $c );
    $self->force_apply_theme( $c );
};

sub force_apply_theme {
    my ( $self, $c ) = @_;

    my $body = $c->res->body;

    # forcibly insert the theme template at the end of the <head>
    # section
    $body =~ s!(?= <\s*/\s*head\s*> )! $self->head              !eix
        or $body =~ s!(?= <\s*body\s*[^\>]*> )! '<head>'.$self->head.'</head>' !eix
        or die "failed to forcibly insert template head section in body:\n$body";

    # and at the very beginning of the body section
    $body =~ s!( <\s*body\s*[^>]*> )    ! "$1\n".$self->body_start !eix
        or die "failed to forcibly insert body start";

    # and at the very end of the body section
    $body =~ s!(?= <\s*/\s*body\s*> )! $self->body_end          !eix
        or die "failed to forcibly insert body end";

    $c->res->body( $body );
}

__PACKAGE__->meta->make_immutable;
1;
