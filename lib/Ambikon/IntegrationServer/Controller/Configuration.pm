package Ambikon::IntegrationServer::Controller::Configuration;

=head1 NAME

Ambikon::IntegrationServer::Controller::Configuration - controller dealing with integration server configuration information

=cut

use Moose;
BEGIN{ extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
  default => 'application/json',
);

=head1 PUBLIC ACTIONS

=head2 all_subsites

Public path: /ambikon/subsite/list

GET: return a hash list of all this integration server's subsites.

=cut

sub all_subsites : ActionClass('REST') Path( '/ambikon/subsite/list' ) {}

sub all_subsites_GET {
    my ( $self, $c ) = @_;
    $c->stash->{rest} = $c->subsites;
}

1;
