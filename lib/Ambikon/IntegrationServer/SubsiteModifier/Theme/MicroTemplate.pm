package Ambikon::IntegrationServer::SubsiteModifier::Theme::MicroTemplate;
use Moose;
use namespace::autoclean;

extends 'Ambikon::IntegrationServer::SubsiteModifier::Text::MicroTemplate';

# endows this postprocessor with fetch_theme, head, body_start, and
# body_end methods
with(qw(
           Ambikon::IntegrationServer::Role::Proxy
           Ambikon::IntegrationServer::Role::TemplateTheme
       ));

# in the template, call this object $theme instead of
# $ambikon_postproc
has '+arg_names' => (
    default => sub { ['ambikon','theme'] },
   );

# need to fetch the theme template before each render
before 'modify_response' => sub {
    $_[0]->fetch_theme( $_[1] );
};

__PACKAGE__->meta->make_immutable;
1;
