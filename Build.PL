#!/usr/bin/perl
use warnings;
use strict;

use Module::Build;

Module::Build->new(
    module_name => 'Bot::BasicBot::Pluggable',
    license => 'perl',
    requires => {
        'perl'              => '5.6.0',
        'Bot::BasicBot'     => '0.30',
        'Test::More'        => '0.01',
        'URI::Title'        => '0.1',
        'URI::Find::Simple' => 0,
        'DBI'               => 0,
        'DBD::SQLite'       => 0,
        'Getopt::Long'      => 0,
        'DBM::Deep'         => 0,
        'XML::Feed'         => 0,
    },
    script_files => [
      'bin/bot-basicbot-pluggable',
    ],
    create_makefile_pl => 'passthrough',
    create_readme => 1,
)->create_build_script;

