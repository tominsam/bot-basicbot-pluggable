#!/usr/bin/perl

# A standard Bot::BasicBot::Pluggable interface. This implements a very
# simple bot, with a 'seen' module, a 'google' module and an 'infobot'
# module.

use warnings;
use strict;
use Bot::BasicBot::Pluggable;

my $bot = Bot::BasicBot::Pluggable->new( channels => [ ],
                                         server => "london.rhizomatic.net",
                                         nick => "jerabot",
                                         );
                                         

$bot->load("Seen");

my $google = $bot->load("Google");
$google->set("google_key", "xxxxxxxxxxxxxxx");

$bot->load("Infobot");

$bot->run();

