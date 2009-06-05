#!perl
use warnings;
use strict;
use Test::More tests => 8;
use Bot::BasicBot::Pluggable::Store::Storable;
use File::Temp qw(tempdir);

my $tmpdir = tempdir( CLEANUP => 1 );

ok( my $store = Bot::BasicBot::Pluggable::Store::Storable->new( dir => $tmpdir), 'creating new store object' );
is( $store->keys('test'), 0, "no keys" );
ok( $store->set("test", "foo", "bar"), "set foo" );
is( $store->keys('test'), 1, "1 key" );
is( $store->get("test", "foo"), "bar", "is set");
ok( $store->set("test", "user_foo", "bar"), "set user_foo" );
is( $store->keys('test'), 2, "2 keys" );
is( $store->keys('test', res => [ '^user' ] ), 1, "1 key" );

