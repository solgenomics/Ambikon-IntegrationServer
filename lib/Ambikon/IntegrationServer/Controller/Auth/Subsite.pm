package Ambikon::IntegrationServer::Controller::Auth::Subsite;
use Moose;
# ABSTRACT: check whether a request comes from an authorized subsite

BEGIN{ extends 'Catalyst::Controller' };

=head1 PRIVATE ACTIONS

=head2 check

Sets C<< $c->stash->{auth}{is_subsite} >>, a boolean indicating whether
this request appears to come from one of our subsites.  Also returns
this value.

=cut

sub check : Chained {
    my ( $self, $c ) = @_;

    my $req_key = $c->req->header('X-Ambikon-Subsite-Key')
                  || $c->req->params->{'subsite_key'};

    # check if a request provides an X-Ambikon-Subsite-Key
    return
        $c->stash->{auth}{is_subsite} =
               $req_key
            && $c->config->{subsite_key}
            && $c->config->{subsite_key} eq $req_key
          ? 1 : 0;

}

1;
