#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Catalyst::Test 'App::Ambikon::IntegrationServer';

ok 1, 'app compiles';

done_testing();
