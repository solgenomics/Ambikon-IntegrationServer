=head1 NAME

Ambikon::IntegrationServer::Controller::Xrefs - controller for Ambikon Xrefs API

=cut

package Ambikon::IntegrationServer::Controller::Xrefs;
use Moose;
use namespace::autoclean;

use JSON::Any; my $json = JSON::Any->new;
use URI::Escape;

BEGIN { extends 'Catalyst::Controller::REST' }

with 'Ambikon::IntegrationServer::Role::Proxy',
     'Ambikon::IntegrationServer::Role::ParallelHTTP';

__PACKAGE__->config(
    #namespace => '/ambikon/xrefs'
    stash_key => 'rest',
    default   => 'application/json',
    );


=head1 PUBLIC ACTIONS

=head2 search_xrefs

Public path: /ambikon/xrefs/search

Valid Method(s): GET

L<Catalyst::Controller::REST> action to request Xrefs from subsites.
Done in parallel with nonblocking HTTP requests.

=head3 Query Params

C<q>: query string to pass to subsites

=cut


sub search_xrefs : Path('/ambikon/xrefs/search') Args(0) ActionClass('REST') {}

sub search_xrefs_GET {
    my ( $self, $c ) = @_;

    my $queries = $c->forward('ensure_queries');

    # proxy it out in parallel to all the subsites that are registered
    # as providing xrefs
    my $responses = {};
    my @jobs = map {
        my $query = $_;
        sub {
            my ( $subsite ) = @_;
            my $response_slot = $responses->{$query}{$subsite->name} = {};
            return $self->_make_subsite_xrefs_request( $c, $subsite, $query, $response_slot );
        }
    } @$queries;

    $self->http_parallel_requests( $c, @jobs );

    # filter out 404 and timeout responses, and validate rest of the responses
    for my $query ( keys %$responses ) {
        my $q_responses = $responses->{$query};
        for my $subsite_name ( keys %$q_responses ) {
            my $response = $q_responses->{$subsite_name};
            if( defined $response->{http_status} && $response->{http_status} != 404 ) {
                # try to decode and validate the result
                eval { $response->{xrefs} = $json->decode( $response->{body} ) };
                if( $@ ) {
                    $self->_set_error_response( $response, 'xref data not valid JSON' );
                } elsif( not $response->{http_status} == 200 ) {
                    $self->_set_error_response( $response, "subsite returned HTTP status $response->{http_status}" );
                } elsif( my @errors = $self->validate_xref_response($response->{xrefs}) ) {
                    $self->_set_error_response( $response, join( ', ', @errors) );
                }
                delete $response->{is_finished};
            } else {
                delete $responses->{$query}{$subsite_name};
            }
        }
    }

    $self->status_ok( $c,
        entity => $responses,
     );

    $c->forward('postprocess_xrefs');
}


########### helper methods and actions ##############

sub ensure_queries :Private {
    my ( $self, $c ) = @_;
    # get our queries from whatever params we got
    my $queries = $c->req->params->{'q'};
    unless( $queries ) {
        $self->status_bad_request( $c,
            message => 'must provide query param "q"'
          );
        return;
    }
    $queries = [$queries] unless ref $queries;

    return  $c->stash->{queries} = $queries;
}


# apply any post-processing to xref responses
sub postprocess_xrefs : Private {
    my ( $self, $c ) = @_;

    # add a default tag of the subsite description, name, or shortname
    # any to xrefs that have no tags
    $c->forward('add_default_xref_tags');
}

# add a default tag of the subsite description, name, or shortname
# any to xrefs that have no tags
sub add_default_xref_tags : Private {
    my ( $self, $c ) = @_;

    my $response = $c->stash->{rest};
    for my $result_set ( values %$response ) {
        for my $subsite_result ( values %$result_set ) {

            my $subsite = $subsite_result->{subsite}
                or next; # skip if no subsite for some reason

            for my $xref ( @{$subsite_result->{xrefs}} ) {
                unless( $xref->{tags} && scalar @{ $xref->{tags} } ) {
                    #warn "making a default tag for ".$subsite->name;
                    @{$xref->{tags}} = scalar @{$subsite->tags} ? @{$subsite->tags}
                                     :    $subsite->description
                                       || $subsite->name
                                       || $subsite->shortname;
                }
            }
        }
    }

}

sub _make_subsite_xrefs_request {
    my ( $self, $c, $subsite, $query, $response_slot ) = @_;

    # set up headers
    my $headers = $self->build_internal_req_headers( $c, $subsite, $c->req->headers );
    $headers->content_type('application/json');
    $headers->header('Accept', [qw[
                                     application/json
                                     application/x-javascript
                                     text/javascript
                                     text/x-javascript
                                     text/x-json
                                 ]]);

    # set up url
    my $url = $subsite->internal_url->clone;
    $url->path_query( $url->path.'/ambikon/xrefs/search?q='.uri_escape( $query ) );

    # initialize the response slot
    @{$response_slot}{qw{ subsite query http_status body is_finished }} = (
        $subsite, $query, undef, '', 0 );

    # assemble and return the completed request args
    return $self->_make_request_args( $url, $headers, $response_slot );
}

sub _make_request_args {
    my ( $self, $url, $headers, $response_slot ) = @_;

    return (
        'GET'      => "$url",
        headers    => $headers,
        on_header  => sub {
            my $headers = shift;
            $response_slot->{http_status} = $headers->{Status};
            $response_slot->{headers} = $headers;
            return 1;
        },
        on_body    => sub { $response_slot->{body} .= $_[0] },
        sub { my ( $data, $headers ) = @_; $response_slot->{is_finished} = 1 },
    );
}

sub _set_error_response {
    my ( $self, $response, $message ) = @_;
    $response->{error_message} = $message;
    $response->{error_content} = delete $response->{xrefs};
}

# return true if the response data is valid, false if not
sub validate_xref_response {
    my ( $self, $response ) = @_;

    return ('response is not an array') unless ref $response eq 'ARRAY';
    for my $xref ( @$response ) {
        # TODO: validate the xref
    }
    return;
}

1;
