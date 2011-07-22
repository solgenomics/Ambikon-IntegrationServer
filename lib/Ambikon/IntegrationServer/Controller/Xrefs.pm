=head1 NAME

Ambikon::IntegrationServer::Controller::Xrefs - controller for Ambikon Xrefs API

=cut

package Ambikon::IntegrationServer::Controller::Xrefs;
use Moose;
use namespace::autoclean;

use AnyEvent::HTTP;
use JSON::Any; my $json = JSON::Any->new;
use URI::Escape;

BEGIN { extends 'Catalyst::Controller::REST' }
with 'Ambikon::IntegrationServer::Role::Proxy';

__PACKAGE__->config(
    #namespace => '/ambikon/xrefs'
    default => 'application/json',
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

sub search_xrefs : Path('/ambikon/xrefs/search') ActionClass('REST') {}

sub search_xrefs_GET {
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

    # proxy it out in parallel to all the subsites that are registered
    # as providing xrefs
    my $cv = AnyEvent->condvar;
    my %responses = map {
        my $query = $_;
        $query => [ map $self->_request_subsite_xrefs( $c, $_, $cv, $query ), values %{$c->subsites} ]
    } @$queries;

    # wait for all the sub-requests to finish
    $cv->recv;

    # aggregate the results and return them
    for my $query_responses ( values %responses ) {
        $query_responses = {
            map {
                my $response = $_;
                # try to decode and validate the result
                my $original_result = $response->{result};
                eval { $response->{result} = $json->decode( $response->{result} ) };
                if( $@ || not $self->validate_xref_response($response->{result}) ) {
                    # the returned xref was not valid.  make it an error
                    $response->{http_status}   = 500;
                    $response->{error_message} = 'the xref data returned from the subsite was not valid';
                    $response->{malformed_result} = $original_result;
                    delete $response->{result};
                }
                delete $response->{is_finished};
                $response->{subsite}->name => $response
            }
            grep $_->{http_status} == 200,
            @$query_responses
        };
    }
    $self->status_ok( $c,
        entity => \%responses,
     );
}

# return true if the response data is valid, false if not
sub validate_xref_response {
    my ( $self, $response ) = @_;

    return 0 unless ref $response eq 'ARRAY';
    for my $xref ( @$response ) {
        # validate the xref
    }
    return 1;
}

sub _request_subsite_xrefs {
    my ( $self, $c, $subsite, $cv, $query ) = @_;

    my $headers = $self->build_internal_req_headers(
        $c,
        $subsite,
        $c->req->headers,
        );
    $headers->content_type('application/json');

    my $response = {
        subsite => $subsite,
        query   => $query,
        http_status  => undef,
        result  => '',
        is_finished => 0,
    };

    my $url = $subsite->internal_url->clone;
    $url->path_query( $url->path.'/ambikon/xrefs/search?q='.uri_escape( $query ) );

    $cv->begin;
    AnyEvent::HTTP::http_request(
        'GET'      => $url,
        headers    => $headers,
        timeout    => 20,
        #body       => $body,
        persistent => 1,
        proxy      => undef, # $ENV{http_proxy} causing test failures
        on_header  => sub {
            my $headers = shift;
            if ( $headers->{Status} !~ /^59\d+/ ) {
                $response->{http_status} = $headers->{Status};
            }
            return 1;
        },
        on_body    => sub {
            $response->{result} .= $_[0];
        },
        sub { $response->{is_finished} = 1; $cv->end },
    );

    return $response;
}


1;
