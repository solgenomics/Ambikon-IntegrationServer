package Ambikon::IntegrationServer::Postprocess::Theme::MicroTemplate;
use Moose;
use namespace::autoclean;

extends 'Ambikon::IntegrationServer::Postprocess::Text::MicroTemplate';

# endows this postprocessor with fetch_theme, head, body_start, and
# body_end methods
with 'Ambikon::IntegrationServer::Role::TemplateTheme';

# in the template, call this object $theme instead of
# $ambikon_postproc
has '+arg_names' => (
    default => sub { ['ambikon','theme'] },
   );

# need to fetch the theme template before each render
before 'render' => sub {
    $_[0]->fetch_theme( $_[1] );
};

__PACKAGE__->meta->make_immutable;
1;
