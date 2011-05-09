package Ambikon::IntegrationServer::Subsite;
# ABSTRACT: integration-server-specific subclass of Ambikon::Subsite

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

use Data::Dump 'dump';

use List::MoreUtils 'all';
use Try::Tiny;

extends 'Ambikon::Subsite';

has '_app' => (
   is       => 'ro',
   isa      => 'ClassName',
   required => 1,
   weak_ref => 1,
  );

=attr modify_conf

Configuration data for this subsite's modifiers.

=cut

has 'modify_conf' => (
    is       => 'ro',
    isa      => 'HashRef|ArrayRef',
    init_arg => 'modify',
    default  => sub {
        +{}
    },
  );

has '_modifier_groups' => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_setup_modifier_groups',
    traits  => ['Array'],
    handles => {
        'modifier_groups' => 'elements',
    },
);

# make sure the modifiers are set up after the object is
# constructed (want to do this at startup time)
sub BUILD {
    shift->_modifier_groups;
}

sub to_list($) {
    ref $_[0] eq 'ARRAY' ? @{$_[0]}: $_[0];
}
sub _setup_modifier_groups {
    my ( $self ) = @_;

    return [
        map {
            my $conf = $_;
            my $rule = $self->_make_rule( $conf->{when} || 'all' );

            my @pp_objects = map {
                my $conf_key = my $rel_class = $_;
                $conf_key =~ s/^\W//;
                $self->_instantiate_modifier( $rel_class, $conf->{$conf_key} )
            } to_list( $conf->{with} || [] );

            { rule => $rule, modifiers => \@pp_objects };
        } to_list $self->modify_conf
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

    die "invalid modifier 'when' rule: '$rule_string'";
}

sub _instantiate_modifier {
    my ( $self, $rel_class, $conf ) = @_;
#    die dump( $self );

    my $class = Catalyst::Utils::resolve_namespace(
        undef,
        (ref($self->_app) || $self->_app).'::SubsiteModifier',
        $rel_class,
        );

    try {
        Class::MOP::load_class( $class )
    } catch {
        die "Could not load class $rel_class ($class) specified in configuration.\n\n" if /Can't locate/;
        die $_;
    };

    return $class->new({
        %{ $conf || {} },
        _app     => $self->_app,
        _subsite => $self,
    });
}

=method modifiers_for( $c )

return the list of modifier objects that should be applied to
the given subsite request/response

=cut

sub modifiers_for {
    my ( $self, $c ) = @_;

    return
        map @{ $_->{modifiers} || [] },
        grep $_->{rule}->( $self, $c ),
        $self->modifier_groups;

}

=method can_stream( $c )

Return true if the data for this request can be streamed to the
client.

Right now, this just tells whether all applicable SubsiteModifiers are
streaming-capable.

=cut

sub can_stream {
    my ( $self, $c ) = @_;
    my @p = $self->modifiers_for( $c );
    return 1 if all { $_->can_stream } @p;
    return 0;
}

__PACKAGE__->meta->make_immutable;
1;
