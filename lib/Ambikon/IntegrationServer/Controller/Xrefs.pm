=head1 NAME

Ambikon::IntegrationServer::Controller::Xrefs - controller for Ambikon Xrefs API

=cut

package Ambikon::IntegrationServer::Controller::Xrefs;
use Moose;
use namespace::autoclean;

use Storable 'dclone';

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

Other query parameters are considered hints, and will be forwarded on
to the subsites unmodified.

=head3 Output

TODO: document data structure here

=cut


sub search_xrefs : Path('/ambikon/xrefs/search') Args(0) ActionClass('REST') {}

sub search_xrefs_GET : Private {
    my ( $self, $c ) = @_;

    $c->forward('common_params');
    $c->forward('query_subsites');
    $c->forward('filter_missing_responses');
    $c->forward('interpret_subsite_responses');
    $c->forward('format_client_response');
}

sub _list(@) {
    map { $_ && ref $_ eq 'ARRAY' ? @$_ : $_ } @_
}
# rearrange the response data if needed based on the 'format' query
# param
sub format_client_response : Private {
    my ( $self, $c ) = @_;

    my ( $format, $responses ) = @{$c->stash}{qw{ format responses }};

    if( $format eq 'flat_array' ) {
        # rearrange the Xrefs to just be a flat list
        $responses = [ map @{$_->{xref_set}->{xrefs} || []}, map values %$_, values %$responses ];
    }
    else {
        # render overall html if they requested html renderings
        if( grep $_ && $_ eq 'text/html', _list $c->stash->{hints}{renderings} ) {
            $c->stash->{xref_set_should_regroup} = sub { ! shift->rendering('text/html') };
            $c->forward('/xrefs/html/group_xrefs');

            $responses->{renderings}{'text/html'} =
                $c->view('Xrefs::HTML')->render_grouped_sets( $c->stash->{xref_sets} );
        }
    }

    # finally, set our response
    $self->status_ok( $c, entity => $responses );
    $c->log->debug( "xrefs response: ".Data::Dump::dump( $responses ) ) if $c->debug;
}


# filter out 404 and empty responses (due to timeouts and such)
sub filter_missing_responses : Private {
    my ( $self, $c ) = @_;

    my $responses = $c->stash->{responses};

    for my $query ( keys %$responses ) {
        my $q_responses = $responses->{$query};
        for my $subsite_name ( keys %$q_responses ) {
            my $response = $q_responses->{$subsite_name};
            unless( defined $response->{http_status} && $response->{http_status} != 404 ) {
                delete $responses->{$query}{$subsite_name};
            }
        }
    }
}

# decode and validate the responses from the subsites, finalize our
# response to the caller
sub interpret_subsite_responses : Private {
    my ( $self, $c ) = @_;
    my $responses = $c->stash->{responses};

    for my $query ( keys %$responses ) {
        my $q_responses = $responses->{$query};
        for my $subsite_name ( keys %$q_responses ) {
            my $response = $q_responses->{$subsite_name};
            $self->decode_and_validate_response( $response );
        }
    }

    $c->forward('postprocess_xrefs');
}

# run the Xref queries on each of the subsites
sub query_subsites :Private {
    my ( $self, $c ) = @_;

    my $queries = $c->stash->{queries};
    my $hints   = $c->stash->{hints};

    my $discriminator = $self->_make_subsite_discriminator( $hints );

    # proxy it out in parallel to all the subsites that are registered
    # as providing xrefs
    my $responses = $c->stash->{responses} = {};
    my @jobs = map {
        my $query = $_;
        sub {
            my ( $c, $subsite ) = @_;
            $responses->{$query} ||= {};
            unless( $discriminator->( $subsite ) ) {
                $c->log->debug( "skipping subsite ".$subsite->name ) if $c->debug;
                return;
            }
            my $response_slot = $responses->{$query}{$subsite->name} = {};
            return $self->_make_subsite_xrefs_request(
                     $c, $subsite, { %$hints, q => $query, }, $response_slot
                   );
        }
    } @$queries;

    $self->http_parallel_requests( $c, @jobs );
}

# process any 'exclude' hint, making a sub ref that returns true if
# the subsite should be queried, false if not.  if no exclude hint,
# just return a sub ref that always returns true.
sub _make_subsite_discriminator {
    my ( $self, $hints ) = @_;
    my %exclude = $self->_hash_param_list( $hints->{subsites_without_tag} );
    my %with    = $self->_hash_param_list( $hints->{subsites_with_tag} );

    return sub { 1 } unless %exclude || %with;

    return sub {
        my ( $subsite ) = @_;
        my @idents = map lc, ( @{ $subsite->tags }, $subsite->name, $subsite->shortname );
        if( %exclude ) {
            for ( @idents ) {
                return 0 if $exclude{$_};
            }
        }
        if( %with ) {
            return 0 unless grep $with{$_}, @idents;
        }
        return 1;
    };
}

# helper method that takes a scalar or arrayref and indexes it into a
# hash-style list like ( elem => 1, elem_2 => 1, ... )
sub _hash_param_list {
    my ( $self, $list ) = @_;
    return unless $list;
    return map { lc $_ => 1 } (
        ref $list ? @$list : ( $list )
    );
}

# helper method to decode and validate the response from a single subsite
sub decode_and_validate_response {
    my ( $self, $response ) = @_;

    # try to decode and validate the result
    my $set;
    eval { $set = $response->{xref_set} = $json->decode( $response->{body} ) };
    if ( $@ ) {
        $self->_set_error_response( $response, 'xref data not valid JSON' );
    } elsif ( not $response->{http_status} == 200 ) {
        $self->_set_error_response( $response, "subsite returned HTTP status $response->{http_status}" );
    } elsif ( my @errors = $self->validate_xref_response( $response->{xref_set} ) ) {
        $self->_set_error_response( $response, join( ', ', @errors) );
    } else {
        # on success, delete the body
        delete $response->{body};

        # add __CLASS__ attributes to the xrefset and xrefs if they don't have them
        $set->{__CLASS__} ||= [ 'Ambikon::XrefSet' ];
        for my $x ( @{ $set->{xrefs} || [] } ) {
            $x->{__CLASS__} ||= [ 'Ambikon::Xref' ];
        }
    }
    delete $response->{is_finished};

}

# helper action to validate our input parameters (from the client or
# subsite that is calling this Xref service)
sub common_params :Private {
    my ( $self, $c ) = @_;

    my $params = dclone $c->req->params;

    # stash our queries
    my $queries = delete $params->{'q'};
    unless( $queries ) {
        $self->status_bad_request( $c,
            message => 'must provide query param "q"'
          );
        return;
    }
    $queries = [$queries] unless ref $queries;
    $c->stash->{queries} = $queries;

    # stash the rest of our params as hints
    $c->stash->{hints} = $params;

    # validate our format param and stash its value as 'format'
    {
        $c->stash->{format} = my $format = $params->{format} || 'default';

        { flat_array => 1, default => 1 }->{$format}
           or $self->status_bad_request( $c,
                message => 'invalid format argument, currently only "array" and "default" are supported',
              );
    }


    return 1;
}


# apply any post-processing to xref responses
sub postprocess_xrefs : Private {
    my ( $self, $c ) = @_;

    # add a default tag of the subsite description, name, or shortname
    # any to xrefs that have no tags
    $c->forward('add_subsite_tags_to_xrefs');

    # filter the xrefs according to any filtering criteria we have
    $c->forward('filter_xrefs');
}

# filter the xrefs according to any filtering criteria we have, also
# deleting any prerenderings that are invalidated by the filtering
sub filter_xrefs : Private {
    my ( $self, $c ) = @_;

    my $hints = $c->stash->{hints};
    my $xref_discriminator;
    if( my %with = $self->_hash_param_list( $hints->{xrefs_with_tag} ) ) {
        $xref_discriminator = $self->_chain_discriminator( $xref_discriminator, sub {
            my $x = shift;
            for ( @{ $x->{tags} || [] } ) {
                return 1 if $with{ lc $_ };
            }
            return 0;
        });
    }
    if( my %without = $self->_hash_param_list( $hints->{xrefs_without_tag} ) ) {
        $xref_discriminator = $self->_chain_discriminator( $xref_discriminator, sub {
            my ( $x ) = @_;
            for( @{ $x->{tags} || [] } ) {
                return 0 if $without{ lc $_ };
            }
            return 1;
        });
    }
    if( my $matching = $self->_combine_regexes( $hints->{xrefs_with_tag_matching} ) ) {
        $xref_discriminator = $self->_chain_discriminator( $xref_discriminator, sub {
            my ( $x ) = @_;
            for ( @{ $x->{tags} || [] } ) {
                return 1 if lc( $_ ) =~ $matching;
            }
            return 0;
        });
    }
    if( my $not_matching = $self->_combine_regexes( $hints->{xrefs_with_tag_not_matching} ) ) {
        $xref_discriminator = $self->_chain_discriminator( $xref_discriminator, sub {
            my ( $x ) = @_;
            for( @{ $x->{tags} || [] } ) {
                return 0 if lc( $_ ) =~ $not_matching
            }
            return 1;
        });
    }
    return unless $xref_discriminator;

    my $response = $c->stash->{responses};
    my $v = Data::Visitor::Callback->new(
        'hash' => sub {
            # filter the xrefs in this set
            my ( $v, $xrefset ) = @_;
            if( my $xrefs = $xrefset->{xrefs} ) {
                my $count_before = @$xrefs;
                # filter the xrefs
                @$xrefs = grep $xref_discriminator->($_), @$xrefs;
                # delete the renderings if we lost some
                if ( $count_before > @$xrefs ) {
                    delete $xrefset->{renderings};
                    delete $response->{renderings};
                }
            } else {
                for ( values %$xrefset ) {
                    $v->visit( $_ );
                }
            }
        },
    )->visit( $response );
}

sub _combine_regexes {
    my ( $self, $regexes ) = @_;
    return unless defined $regexes;
    $regexes = [ $regexes ] unless ref $regexes eq 'ARRAY';
    s/[^\w\d\s\.\\(\)[\]\{\}\\]//g for @$regexes; #< sanitize the input
    my $qr = 'qr/('.join('|',@$regexes).')/i';
    warn "generated qr $qr\n";
    $qr = eval $qr;
    die $@ if $@;
    return $qr;
}

sub _chain_discriminator {
    my ( $self, $existing, $additional ) = @_;
    return $existing ? sub { $existing->(@_) && $additional->(@_) } : $additional;
}

# add the subsite's tags to xrefs and xrefsets if it has them, and if
# the xref or xrefset has no tags at all, make sure it has at least
# one, using the subsite description, name, or shortname as a tag if
# necessary
sub add_subsite_tags_to_xrefs : Private {
    my ( $self, $c ) = @_;

    my $response = $c->stash->{responses};
    for my $result_set ( values %$response ) {
        for my $subsite_result ( values %$result_set ) {

            my $subsite = $subsite_result->{subsite}
                or next; # skip if no subsite for some reason

            next unless $subsite_result->{xref_set};

            for my $thing ( $subsite_result->{xref_set}, @{$subsite_result->{xref_set}{xrefs}} ) {

                # add the subsite's tags to the end
                push @{ $thing->{tags} ||= [] }, @{$subsite->tags};

                # use the subsite's other attributes as tags if necessary
                unless( $thing->{tags} && scalar @{ $thing->{tags} } ) {
                    #warn "making a default tag for ".$subsite->name;
                    @{$thing->{tags}} = ( $subsite->description
                                         || $subsite->name
                                         || $subsite->shortname,
                                       );
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
    $url->path( $url->path.'/ambikon/xrefs/search' );
    $url->query_form( $query );

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
        headers    => $self->bare_headers_hashref( $headers ),
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
    delete $response->{xref_set};
}

# return true if the response data is valid, false if not
sub validate_xref_response {
    my ( $self, $response ) = @_;

    return ('response is not a hashref') unless ref $response eq 'HASH';
    for my $xref ( @{ $response->{xrefs} || [] } ) {
        # TODO: validate the xref
    }

    return;
}

1;
