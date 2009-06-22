package Test::Bot::BasicBot::Pluggable::Store;
use base qw(Test::Builder::Module);

our $VERSION = '0.1';

our @EXPORT = qw(store_ok);

sub store_ok {
	my ($store_class,$store_args) = @_;
	my $test = __PACKAGE__->builder;
	$test->plan(tests => 9);
	$test->ok(eval "require Bot::BasicBot::Pluggable::Store::$store_class",'loading store class');
	$test->ok(my $store = "Bot::BasicBot::Pluggable::Store::$store_class"->new(%{$store_args}),'creating store object');
	$test->is_num( scalar $store->keys('test'), 0 , 'no keys set initially' );
	$test->ok( $store->set("test", "foo", "bar"), "set foo to bar" );
	$test->is_num( scalar $store->keys('test'), 1, "storage namespace has 1 key" );
	$test->is_eq( $store->get("test", "foo"), "bar", "foo is set to bar");
	$test->ok( $store->set("test", "user_foo", "bar"), "set user_foo also to bar" );
	$test->is_num( scalar $store->keys('test'), 2, "storage namespace has 2 keys" );
	$test->is_num( scalar $store->keys('test', res => [ '^user' ] ), 1, "storage namespace has one key matching ^user" );
}

1;
