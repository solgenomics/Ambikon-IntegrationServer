=head1 NAME

Ambikon::IntegrationServer::View::Xrefs::HTML - default HTML view for a set of xrefs

=cut

package Ambikon::IntegrationServer::View::Xrefs::HTML;
use Moose;
extends 'Catalyst::View';

use List::MoreUtils 'uniq';

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

    #warn "rendering sets: ".Data::Dump::dump( $sets );

    my $whole_body = join_lines (
        qq|<dl class="ambikon_xref ambikon">|,
        ( map {
            ( qq|   <dt class="ambikon_xref ambikon">$_</dt>|,
              qq|       <dd>|,
              join_lines( uniq( map $self->xref_set_html( $_ ), @{ $sets->{$_} } ) ),
              qq|       </dd>|,
            )
          } sort keys %$sets,
        ),
        qq|</dl>|,
      );

    $c->res->status(200);
    $c->res->content_type('text/html');
    $c->res->body( $whole_body );
}

sub xref_set_html {
    my ( $self, $set ) = @_;

    # use the xref set's rendering if it has one
    # otherwise make a default one
    return $set->rendering('text/html')
        || join '', map "$_\n", (
               '<div class="ambikon_xref_set ambikon">',
               uniq( map $self->xref_html( $_ ), @{$set->xrefs} ),
               '</div>',
             );

}
sub xref_html {
    my ( $self, $xref ) = @_;

    return $xref->rendering('text/html')
        || qq|<a class="ambikon_xref ambikon" href="$xref->{url}">$xref->{text}</a>|;
}

1;
