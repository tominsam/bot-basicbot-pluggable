#!/usr/bin/perl
use warnings;
use strict;
use lib qw(./lib);

use Test::More no_plan => 1;

use_ok('Bot::BasicBot::Pluggable');
use_ok('Bot::BasicBot::Pluggable::Module::Base');

ok(my $base = Bot::BasicBot::Pluggable::Module::Base->new(), "created base module");
ok($base->var('test', 'value'), "set variable");
ok($base->var('test') eq 'value', 'got variable');
ok($base->save(), "saved settings");

ok($base = Bot::BasicBot::Pluggable::Module::Base->new(), "created new base module");
ok($base->var('test') eq 'value', 'got old variable');

ok($base->unset('test'), 'unset variable');
ok(!defined($base->var('test')), "it's gone");

# very hard to do anything but check existence of these methods
ok($base->can($_), "'$_' exists")
  for (qw(said connected tick emoted init));

ok($base->help, "help returns something");

ok(unlink("Base.storable"), "Settings file deleted");
