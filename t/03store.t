#!perl
use warnings;
use strict;
use Test::More no_plan => 1;

use Bot::BasicBot::Pluggable::Store;
ok( my $store = Bot::BasicBot::Pluggable::Store->new );
is( $store->keys('test'), 0, "no keys" );
ok( $store->set("test", "foo", "bar"), "set foo" );
is( $store->keys('test'), 1, "1 keys" );
is( $store->get("test", "foo"), "bar", "is set");
