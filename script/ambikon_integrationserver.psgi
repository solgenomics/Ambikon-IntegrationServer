#!/usr/bin/env perl
use strict;
use warnings;

use Plack::Builder;

use Ambikon::IntegrationServer;

Ambikon::IntegrationServer->setup_engine('PSGI');
my $app = sub { Ambikon::IntegrationServer->run(@_) };

builder {
    enable "Deflater", content_type => [ 'text/html', 'text/css', 'text/javascript', 'application/javascript', 'application/x-javascript' ];

    enable sub {
	my $app = shift;
	sub {
	    my $env = shift;
	    $app->($env);
	};
    };
    $app;
};
