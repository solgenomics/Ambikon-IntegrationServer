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


sub search_xrefs : Path('/ambikon/xrefs/search') ActionClass('REST') {}

sub search_xrefs_GET {
    my ( $self, $c ) = @_;

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

    while( grep !$_->{is_finished}, map @$_, values %responses ) {
        # wait for all the sub-requests to finish
        $cv->recv;
    }

    # aggregate the results and return them
    for my $query_responses ( values %responses ) {
        $query_responses = {
            map {
                my $response = $_;
                $response->{result} = eval { $json->decode( $response->{result} ) } || $response->{result};
                delete $response->{is_finished};
                $response->{subsite}->name => $response
            }
            grep $_->{status} == 200,
            @$query_responses
        };
    }
    $self->status_ok( $c,
        entity => \%responses,
     );
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
        status  => undef,
        result  => '',
        is_finished => 0,
    };

    my $url = $subsite->internal_url->clone;
    $url->path_query( $url->path.'/ambikon/xrefs/search?q='.uri_escape( $query ) );

    AnyEvent::HTTP::http_request(
        'GET'      => $url,
        headers    => $headers,
        timeout    => 30,
        #body       => $body,
        persistent => 1,
        proxy      => undef, # $ENV{http_proxy} causing test failures
        on_header  => sub {
            my $headers = shift;
            if ( $headers->{Status} !~ /^59\d+/ ) {
                $response->{status} = $headers->{Status};
            }
            return 1;
        },
        on_body    => sub {
            $response->{result} .= $_[0];
        },
        sub { $response->{is_finished} = 1; $cv->send },
    );

    return $response;
}


1;
