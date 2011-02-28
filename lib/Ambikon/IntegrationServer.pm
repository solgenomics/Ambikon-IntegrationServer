package Ambikon::IntegrationServer;
use Moose;
use namespace::autoclean;

use Ambikon::Subsite;

use Catalyst::Runtime 5.80;

use Catalyst (
    #'-Debug',
    'ConfigLoader',
    'Static::Simple',
  );

extends 'Catalyst';

our $VERSION = '0.01';

__PACKAGE__->config(
    name => 'Ambikon::IntegrationServer',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
);

# our subsites, hashed by the subsite name
{
    my $subsites;
    sub subsites {
        unless( $subsites ) {
            $subsites = {};
            my $c = shift;
            while ( my ( $shortname, $ss_conf ) = each %{ $c->config->{subsite} || {} } ) {
                $subsites->{$shortname} = Ambikon::Subsite->new({
                    %$ss_conf,
                    shortname => $shortname,
                });
            }
        }
        return $subsites;
    }
}

# Start the application
__PACKAGE__->setup();

=head1 NAME

Ambikon::IntegrationServer - Catalyst based application

=head1 SYNOPSIS

    script/app_ambikon_integrationserver_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<Ambikon::IntegrationServer::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Robert Buels,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
