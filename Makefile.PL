#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install 1.02;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'Murakumo';
all_from 'lib/Murakumo.pm';

requires 'Catalyst::Runtime' => '5.90007';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Config::General'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats

requires 'Config::General';
requires 'DBIx::Class';
requires 'DBIx::Class::Schema::Loader';
requires 'Data::UUID';
requires 'DateTime';
requires 'FindBin';
requires 'JSON';
requires 'JSON::XS';
requires 'LWP::UserAgent';
requires 'Log::Log4perl';
requires 'Log::Log4perl::Catalyst';
requires 'Module::Install::Catalyst';
requires 'Moose';
requires 'Path::Class';
requires 'URI';
requires 'URI::Escape';
requires 'XML::TreePP';
requires 'YAML';

test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
