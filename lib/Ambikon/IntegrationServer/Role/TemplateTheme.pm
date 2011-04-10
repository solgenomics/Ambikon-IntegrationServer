package Ambikon::IntegrationServer::Role::TemplateTheme;
use Moose::Role;
use namespace::autoclean;

use Carp;

use LWP::Simple ();

requires '_app';

has 'theme_from_subsite' => (
    is       => 'rw',
    isa      => 'Str',
    trigger  => sub { shift->clear_theme_url },
    );

has 'theme_url' => (
    is         => 'rw',
    isa        => 'URI',
    lazy_build => 1,
    );

for (qw( head body_start body_end )) {
    has $_ => (
        is  => 'rw',
        isa => 'Str',
        );
}

# infers the theme_url from other conf vars if necessary
sub _build_theme_url {
    my ( $self ) = @_;
    my $class = ref $self || $self;

    my $c = $self->_app;

    $self->theme_from_subsite
       or die "either theme_url or theme_from_subsite conf var must be set for $class";

    my $subsite_config_key = $class;
    { my $prefix = (ref( $c ) || $c ).'::Post[^:]+::';
      $subsite_config_key =~ s/^$prefix// or die "$prefix, $subsite_config_key";
    }

    my $subsite = $c->subsites->{ $self->theme_from_subsite }
        or croak "subsite ".$self->theme_from_subsite." does not exist";
    my $subsite_theme_config = $subsite->config->{ $subsite_config_key }
        or croak "missing $subsite_config_key configuration in '".$subsite->shortname."' subsite";
    my $theme_url   = $subsite->internal_url->clone;
    my $theme_pathq = $subsite_theme_config->{theme_url}
        or croak "missing theme_url in ".$subsite->shortname." $subsite_config_key config";
    $theme_url->path_query( $theme_url->path.$theme_pathq );

    return $theme_url;
}

sub fetch_theme {
    my ( $self, $c ) = @_;

    my $theme_url  = $self->theme_url;
    my $theme_text = LWP::Simple::get( $theme_url )
        or croak "failed to fetch theme from internal url '$theme_url'";

    $self->_parse_theme_parts( $theme_text );
}

sub _parse_theme_parts {
    my ( $self, $theme_text ) = @_;

    my ( undef, $head, undef, $start_body, $end_body ) = split m( </?(?:body|head)> |  <\s*!\s*--\s*AMBIKON_CONTENT\s*--\s*> )ix, $theme_text
       or die "could not parse theme template:\n$theme_text";

    $self->head( $head );
    $self->body_start( $start_body );
    $self->body_end( $end_body );

}

1;