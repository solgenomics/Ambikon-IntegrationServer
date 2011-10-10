=head1 NAME

Ambikon::IntegrationServer::View::Xrefs::HTML - default HTML view for a set of xrefs

=cut

package Ambikon::IntegrationServer::View::Xrefs::HTML;
use Moose;
extends 'Catalyst::View';

use List::MoreUtils 'uniq';

use Ambikon::View::Xrefs::HTML;

has '_inner' => (
  is  => 'ro',
  lazy_build => 1,
  handles => [qw[
      xref_response_html
      xref_set_html
      xref_html
  ]
  ],
);

sub _build__inner {
    Ambikon::View::Xrefs::HTML->new;
}

sub join_lines(@) {
    join '', map "$_\n", @_
}

=head1 METHODS

=head2 process

Takes a set of L<Ambikon::XrefSet> objects in the stash under C<<
$c->stash->{xref_sets} >> and renders them as HTML.

=cut

sub process {
    my ( $self, $c ) = @_;

    my $sets = $c->stash->{xref_sets} || {};

    warn "rendering sets: ".Data::Dump::dump( $sets );

    my $whole_body = $self->render_grouped_sets( $sets );

    $c->res->status( 200 );
    $c->res->content_type( 'text/html' );
    $c->res->body( $whole_body );
}

sub render_grouped_sets {
    my ( $self, $sets ) = @_;

    my $whole_body = join_lines (
        qq|<dl class="ambikon_xref ambikon">|,
        ( map {
            ( qq|   <dt class="ambikon_xref ambikon">$_</dt>|,
              qq|       <dd>|,
              join_lines( uniq( map $self->xref_set_html( $_ ), grep !$_->is_empty, @{ $sets->{$_} } ) ),
              qq|       </dd>|,
            )
          } sort keys %$sets,
        ),
        qq|</dl>|,
      );

    return $whole_body;
}


1;
