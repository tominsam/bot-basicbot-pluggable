#!perl
use warnings;
use strict;
use Test::More tests => 9;

use Bot::BasicBot::Pluggable::Store;
use Bot::BasicBot::Pluggable::Store::Deep;
unlink('t/deep.db') if (-e 't/deep.db');



ok( my $store = Bot::BasicBot::Pluggable::Store::Deep->new( file => 't/deep.db' ) );
is( $store->keys('test'), 0, "no keys" );
ok( $store->set("test", "foo", "bar"), "set foo" );
is( $store->keys('test'), 1, "1 key" );
is( $store->get("test", "foo"), "bar", "is set");

ok( $store->set("test", "user_foo", "bar"), "set user_foo" );
is( $store->keys('test'), 2, "2 keys" );
is( $store->keys('test', res => [ '^user' ] ), 1, "1 key" );



eval {
	my $tmp = Bot::BasicBot::Pluggable::Store::Deep->new(); 
};

like($@, qr/You must pass a filename/, "Catch no file passed into 'new'");
