#!/usr/bin/perl
use warnings;
use strict;

use Module::Build;

Module::Build->new(
    module_name => 'Bot::BasicBot::Pluggable',
    license => 'perl',
    requires => {
        'perl'        => '5.6.0',
        'Bot::BasicBot' => '0.07',
        'Test::More' => 0,
        'Pod::Coverage' => 0,
    },
    create_makefile_pl => 'traditional',
)->create_build_script;

