package Ambikon::IntegrationServer::Controller::Xrefs::HTML;
use Moose;

BEGIN { extends 'Ambikon::IntegrationServer::Controller::Xrefs' }

__PACKAGE__->config(
    #namespace => '/ambikon/xrefs/html',
  );

use Data::Visitor::Callback;

use Ambikon::XrefSet;
use Ambikon::ServerHandle;

=head2 search_xrefs_html

Public path: /ambikon/xrefs/search_html

Valid Method(s): GET

Same arguments as L<search_xrefs>, but returns only HTML containing a
basic rendering of the Xrefs that were returned.  This is a convenient
way to get up and running quickly for applications that merely want to
pass a view of the Xrefs directly on to a user.

Done in parallel with nonblocking HTTP requests.

=head3 Query Params

C<q>: query string to pass to subsites

=cut

sub search_xrefs_html : Path('/ambikon/xrefs/search_html') Args(0) {
    my ( $self, $c ) = @_;

    # call the search_xrefs on each site with a hint that we would
    # like text/html renderings

    # make default renderings for any xrefs that don't have them
    $c->req->params->{renderings} = 'text/html';
    $c->forward( 'search_xrefs' );
    $c->forward( 'assemble_renderings' );
}

sub assemble_renderings : Private {
    my ( $self, $c ) = @_;

    # break up and regroup xref sets that do not have their own
    # text/html rendering
    $c->stash->{xref_set_should_regroup} = sub { ! shift->rendering('text/html') };
    $c->forward('group_xrefs');

    $c->forward('View::Xrefs::HTML');
}

sub group_xrefs : Private {
    my ( $self, $c ) = @_;

    # ALGORITHM
    # * for each xref set:
    #   - if the set has a rendering, keep it together, and make a
    #     primary tag for it if necessary
    #   - otherwise, break it up and add the xrefs to the 'general'
    #     ones, setting their primary tag to the xrefset's tag if it has one
    # * go through general xrefs, group them into xref sets by their primary tags
    # * make final response as a <dl> of category and rendered xref
    #   set (rendering being either site-provided or default)

    my $responses =
        Ambikon::ServerHandle->inflate_xref_search_result( $c->stash->{responses} );

    #warn "grouping responses: ".Data::Dump::dump( $responses );

    my @general_xrefs;
    my %sets;

    my $discriminator = $c->stash->{xref_set_should_regroup};

    # categorize pre-rendered xref sets, and add xrefs from
    # non-rendered sets to the general pool
    Data::Visitor::Callback->new( 'Ambikon::XrefSet' => sub {
       my ( undef, $set ) = @_;
       if( ! $discriminator || ! $discriminator->( $set ) ) {
           my $tag = $set->primary_tag
                  || $set->subsite && ( $set->subsite->description
                                        || $set->subsite->name
                                        || $set->subsite->shortname
                                      );

           push @{$sets{ $tag }}, $set;
       } else {
           # add the set's primary tag, if it has one, to the xrefs's
           # tags
           if( my $set_pt = $set->primary_tag ) {
               for (@{ $set->xrefs }) {
                   $_->add_tag( $set_pt );
               }
           }

           # and add all the xrefs to the general pool for
           # re-categorization
           push @general_xrefs, @{ $set->xrefs };
       }
    })->visit( $responses );

    # categorize the general pool of xrefs by primary tag
    my %general_categorized;
    for my $x ( @general_xrefs ) {
        my $tag = $x->primary_tag
                  || $x->subsite->primary_tag
                  || 'General';

        ( $general_categorized{ $tag } ||= Ambikon::XrefSet->new )->add_xref( $x );
    }

    # now merge the general sets into the non-regrouped sets
    for my $category ( keys %general_categorized ) {
        push @{$sets{$category}}, $general_categorized{ $category };
    }

    $c->stash->{xref_sets} = \%sets;
}

1;
