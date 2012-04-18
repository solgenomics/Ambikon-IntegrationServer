package Ambikon::IntegrationServer::Role::TemplateTheme;
use Moose::Role;
use namespace::autoclean;

use Carp;

use AnyEvent::HTTP;
use List::Util 'max';
use Moose::Util::TypeConstraints;
use DateTimeX::Easy ();
use MooseX::Types::URI 'Uri';

requires '_app', 'build_internal_req_headers', 'modify_response';

has 'theme_from_subsite' => (
    is       => 'rw',
    isa      => 'Str',
    trigger  => sub { shift->clear_theme_url },
    );

has 'theme_url' => (
    is         => 'rw',
    isa        => Uri,
    coerce     => 1,
    lazy_build => 1,
    );

for (qw( head body_start body_end )) {
    has $_ => (
        is  => 'rw',
        isa => 'Str',
        );
}

{
    my $lm_date = subtype as 'DateTime';
    coerce $lm_date, from 'Str', via { DateTimeX::Easy->new( $_ ) };

    has 'last_modified' => (
        is  => 'rw',
        isa => $lm_date,
        coerce => 1,
     );
}
after 'modify_response' => sub {
    my ( $self, $c ) = @_;
    $c->res->headers->remove_header('ETag','Accept-Ranges');

    # if both the template and the current response have last-modified set,
    # set it to be the later of the two, otherwise remove it
    my $res_modified = $c->res->headers->last_modified;
    $c->res->headers->remove_header('Last-Modified');
    if( $res_modified && $self->last_modified ) {
        $c->res->headers->last_modified( max $self->last_modified->epoch, $res_modified );
    }

};

# infers the theme_url from other conf vars if necessary
sub _build_theme_url {
    my ( $self ) = @_;
    my $class = ref $self || $self;

    my $c = $self->_app;

    $self->theme_from_subsite
       or die "either theme_url or theme_from_subsite conf var must be set for $class";

    my $subsite_config_key = $class;
    { my $prefix = (ref( $c ) || $c ).'::SubsiteModif[^:]+::';
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

    my $subsite = $c->stash->{subsite}
        or croak "subsite not present in stash";

    my $theme_url = $self->theme_url;
    my $headers   = $self->build_internal_req_headers( $c, $subsite, $c->req->headers );

    my $cv = AnyEvent->condvar;
    AnyEvent::HTTP::http_request(
        'GET'      => $theme_url,
        headers    => $headers,
        persistent => 0,
        proxy      => undef,
        sub {
            my ( $body, $headers ) = @_;
            if ( $headers->{Status} == 200 ) {
                $self->_parse_theme_parts( $body );
                $self->last_modified( $headers->{'last-modified'} ) if $headers->{'last-modified'};
            } else {
                $c->log->error(ref($self).": HTTP $headers->{Status} fetching theme from ".($self->theme_from_subsite || 'manually-specified')." back end URL: $theme_url");
            }
            $cv->send;
        }
     );
    $cv->recv;
}

sub _parse_theme_parts {
    my ( $self, $theme_text ) = @_;

    my ( undef, $head, undef, $start_body, $end_body ) = split m( </?(?:body|head)> |  <\s*!\s*--\s*AMBIKON_CONTENT\s*--\s*> )ix, $theme_text;

    $head && $start_body && $end_body
       or die "could not parse theme template:\n$theme_text";

    $self->head( $head );
    $self->body_start( $start_body );
    $self->body_end( $end_body );
}

1;
