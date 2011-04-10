package Ambikon::IntegrationServer::Subsite;
# ABSTRACT: integration-server-specific subclass of Ambikon::Subsite

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

use Data::Dump 'dump';

use List::MoreUtils 'any';

extends 'Ambikon::Subsite';

has '_app' => (
   is       => 'ro',
   isa      => 'ClassName',
   required => 1,
   weak_ref => 1,
  );

=attr postprocess_conf

Configuration data for this subsite's request postprocessing.

=cut

has 'postprocess_conf' => (
    is       => 'ro',
    isa      => 'HashRef|ArrayRef',
    init_arg => 'postprocess',
    default  => sub {
        +{}
    },
  );

has '_postprocessor_groups' => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_setup_postprocessor_groups',
    traits  => ['Array'],
    handles => {
        'postprocessor_groups' => 'elements',
    },
);

# make sure the postprocessors are set up after the object is
# constructed (want to do this at startup time)
sub BUILD {
    shift->_postprocessor_groups;
}

sub to_list($) {
    ref $_[0] eq 'ARRAY' ? @{$_[0]}: $_[0];
}
sub _setup_postprocessor_groups {
    my ( $self ) = @_;

    return [
        map {
            my $conf = $_;
            my $rule = $self->_make_rule( $conf->{when} || 'all' );

            my @pp_objects = map {
                my $conf_key = my $rel_class = $_;
                $conf_key =~ s/^\W//;
                $self->_instantiate_postprocessor( $rel_class, $conf->{$conf_key} )
            } to_list( $conf->{with} || [] );

            { rule => $rule, postprocessors => \@pp_objects };
        } to_list $self->postprocess_conf
    ];
}

sub _make_rule {
    my ( $self, $rule_string ) = @_;

    # 'all' rule
    return sub { 1 } if lc $rule_string eq 'all';

    # content-type rule
    if( my ( $type ) = $rule_string =~ /^content[_\-]type\s*:?\s*(.+)$/ ) {
        $type = lc $type;
        return sub {
            my ( $this, $c ) = @_;
            return lc $c->res->content_type eq lc $type;
        };
    }

    die "invalid postprocessing 'when' rule: '$rule_string'";
}

sub _instantiate_postprocessor {
    my ( $self, $rel_class, $conf ) = @_;
#    die dump( $self );

    my $class = Catalyst::Utils::resolve_namespace(
        undef,
        (ref($self->_app) || $self->_app).'::Postprocess',
        $rel_class,
        );

    Class::MOP::load_class( $class );

    return $class->new({
        %{ $conf || {} },
        _app     => $self->_app,
        _subsite => $self,
    });
}

=method postprocessors_for( $c )

return the list of postprocessor objects that should be applied to
data in the given request

=cut

sub postprocessors_for {
    my ( $self, $c ) = @_;

    return
        map @{ $_->{postprocessors} || [] },
        grep $_->{rule}->( $self, $c ),
        $self->postprocessor_groups;

}

=method should_stream( $c )

Return true if the data for this request should be streamed directly
the client.

=cut

sub should_stream {
    my ( $self, $c ) = @_;
    my @p = $self->postprocessors_for( $c );
    return 0 if any { ! $_->can_stream } @p;
    return 1;
}

__PACKAGE__->meta->make_immutable;
1;
