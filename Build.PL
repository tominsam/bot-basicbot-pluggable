#!/usr/bin/perl
use warnings;
use strict;

use Module::Build;

Module::Build->new(
    module_name => 'Bot::BasicBot::Pluggable',
    license     => 'perl',
    requires    => {
        'perl'              => '5.8.0',
        'Bot::BasicBot'     => '0.30',
        'Test::More'        => '0.01',
        'URI::Title'        => '0.1',
        'URI::Find::Simple' => 0,
        'DBI'               => 0,
        'DBD::SQLite'       => 0,
        'Getopt::Long'      => 0,
        'DBM::Deep'         => 0,
        'Text::Unidecode'   => 0,
	'LWP::UserAgent'    => 0,
    },
    recommends         => { 'XML::Feed' => 0, },
    script_files       => [ 'bin/bot-basicbot-pluggable', ],
    create_makefile_pl => 'passthrough',
    create_readme      => 1,
    meta_merge         => {
        resources => {
            repository => 'http://github.com/jerakeen/bot-basicbot-pluggable',
        },
        author => ['Mario Domgoergen <mario@domgoergen.com>']
    }
)->create_build_script;

