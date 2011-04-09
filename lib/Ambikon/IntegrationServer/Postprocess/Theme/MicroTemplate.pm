package Ambikon::IntegrationServer::Postprocess::Theme::MicroTemplate;
use Moose;
use namespace::autoclean;

use Carp;

use LWP::Simple;

extends 'Ambikon::IntegrationServer::Postprocess::Text::MicroTemplate';

has 'theme_from_subsite' => (
    is  => 'ro',
    isa => 'Str',
);

has '+arg_names' => (
    default => sub { ['ambikon','theme'] },
   );

for (qw( head body_start body_end )) {
    has $_ => (
        is  => 'rw',
        isa => 'Str',
        );
}

before 'render' => sub {
    $_[0]->fetch_theme( $_[1] );
};

sub fetch_theme {
    my ( $self, $c ) = @_;
    my $subsite = $c->subsites->{ $self->theme_from_subsite }
        or croak "subsite ".$self->theme_from_subsite." does not exist";

    my $subsite_config_key = ref( $self );
    { my $prefix = (ref( $c ) || $c ).'::Post[^:]+::';
      $subsite_config_key =~ s/^$prefix// or die "$prefix, $subsite_config_key";
    }
    my $subsite_theme_config = $subsite->config->{ $subsite_config_key }
        or croak "missing $subsite_config_key configuration in '".$subsite->shortname."' subsite";
    my $theme_url   = $subsite->internal_url->clone;
    my $theme_pathq = $subsite_theme_config->{theme_url}
        or croak "missing theme_url in ".$subsite->shortname." $subsite_config_key config";
    $theme_url->path_query( $theme_url->path.$theme_pathq );

    my $theme_text = get $theme_url
        or die "could not fetch $subsite_config_key theme from ".$subsite->shortname." theme_url $theme_url";

    $self->_extract_theme_parts( $theme_text );
}

sub _extract_theme_parts {
    my ( $self, $theme_text ) = @_;

    my ( undef, $head, undef, $start_body, $end_body ) = split m( </?(?:body|head)> |  <\s*!\s*--\s*AMBIKON_CONTENT\s*--\s*> )ix, $theme_text
       or die "could not parse theme template:\n$theme_text";

    $self->head( $head );
    $self->body_start( $start_body );
    $self->body_end( $end_body );

}

__PACKAGE__->meta->make_immutable;
1;
