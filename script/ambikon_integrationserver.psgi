#!/usr/bin/env perl
use strict;
use warnings;
use Ambikon::IntegrationServer;

Ambikon::IntegrationServer->setup_engine('PSGI');
my $app = sub { Ambikon::IntegrationServer->run(@_) };

