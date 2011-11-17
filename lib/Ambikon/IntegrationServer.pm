package Ambikon::IntegrationServer;
use Moose;
use namespace::autoclean;

use Ambikon::IntegrationServer::Subsite;

use Catalyst::Runtime 5.80;

use Catalyst (
    #'-Debug',
    'ConfigLoader',
    'Static::Simple',
  );

extends 'Catalyst';

our $VERSION = '0.01';

sub version {
    (our $VERSION) || 'dev'
}

sub version_string {
    'Ambikon/'.$_[0]->version.'';
}

__PACKAGE__->config(
    name => 'Ambikon::IntegrationServer',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
);

# lazy accessor for our subsite objects, hashed by the subsite name
{
    my $subsites;
    sub subsites {
        unless( $subsites ) {
            $subsites = {};
            my $c = shift;
            while ( my ( $shortname, $ss_conf ) = each %{ $c->config->{subsite} || {} } ) {
                my $ss = $subsites->{$shortname} = Ambikon::IntegrationServer::Subsite->new({
                    %$ss_conf,
                    shortname => $shortname,
                    _app      => $c,
                });
            }
        }
        return $subsites;
    }
}

# Start the application
__PACKAGE__->setup();

=head1 NAME

Ambikon::IntegrationServer - the Ambikon integration server

=head1 SYNOPSIS

    script/ambikon_integrationserver_server.pl

=head1 DESCRIPTION

The Ambikon integration server is a fast frontend web application for
integrating other web applications.  Existing web applications can run
unmodified under Ambikon.  Web applications that are Ambikon-aware can
use it as a central point of exchange for communicating with other web
applications running as part of the same web site.

=cut

1;
