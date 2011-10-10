package Ambikon::IntegrationServer::Role::ParallelHTTP;
use Moose::Role;

use AnyEvent::HTTP;

requires 'build_internal_req_headers';

sub http_parallel_requests {
    my ( $self, $c, @jobs ) = @_;

    my $cv = AnyEvent->condvar;

    my $jobs = 0;
    for my $subsite ( values %{ $c->subsites } ) {

        my $default_headers = $self->build_internal_req_headers(
            $c,
            $subsite,
            $c->req->headers,
            );

        for my $job ( @jobs ) {

            my ( $method, $url, @ae_http_args ) = $job->( $subsite );

            next unless $method; #< job returns nothing if it wants to skip this subsite
            $jobs++;

            # make sure the ending subroutine is present, and calls $cv->end
            my $end_sub;
            if( scalar @ae_http_args % 2 ) {
                my $original_end = pop @ae_http_args;
                $end_sub = sub { $original_end->(); $cv->end };
            } else {
                $end_sub = sub { $cv->end };
            }

            my %ae_args = (
                headers    => $default_headers,
                timeout    => 20,
                persistent => 1,
                proxy      => undef,
                @ae_http_args,
              );

            #warn "dispatching with: ".Data::Dump::dump( \%ae_args, $end_sub );

            $cv->begin;
            AnyEvent::HTTP::http_request(
                $method => $url,
                %ae_args,
                $end_sub,
              );
        }
    }

    # now wait for all the req
    $cv->recv if $jobs;
}

1;
