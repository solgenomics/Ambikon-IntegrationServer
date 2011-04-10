#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'Ambikon-IntegrationServer';
all_from 'lib/Ambikon/IntegrationServer.pm';

requires      'Ambikon::Subsite' => 0;
requires      'AnyEvent::HTTP' => 0;
requires      'Catalyst::Action::RenderView';
requires      'Catalyst::Component::ApplicationAttribute' => 0;
requires      'Catalyst::Runtime' => '5.80031';
requires      'Catalyst::Plugin::ConfigLoader';
requires      'Catalyst::Plugin::Static::Simple';
requires      'Config::General'; # This should reflect the config file format you've chosen
requires      'Data::Dump' => 0;
requires      'List::MoreUtils' => 0;
requires      'LWP::Simple' => 0;
requires      'Moose' => 0;
requires      'Moose::Role' => 0;
requires      'Moose::Util::TypeConstraints' => 0;
requires      'namespace::autoclean' => 0;
test_requires 'aliased' => 0;
test_requires 'Catalyst::Test' => 0;
test_requires 'File::Temp' => 0;
test_requires 'IO::String' => 0;
test_requires 'JSON::Any' => 0;
test_requires 'parent' => 0;
test_requires 'Plack::Loader' => 0;
test_requires 'Test::MockObject' => 0;
test_requires 'Test::More' => '0.88';
test_requires 'Test::TCP' => 0;

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
