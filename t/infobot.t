#!perl
use warnings;
use strict;
use lib qw(lib t/lib);
use Test::More no_plan => 1;
use FindBin qw( $Bin );

use Bot::BasicBot::Pluggable::Module::Infobot;
use Bot::BasicBot::Pluggable::Store;


# Fake a bot store into the Module base class, so we don't have to mess around
# with Bot bojects at this point. Use a non-persisting store, it's safe.
my $store;
no warnings 'redefine';
sub Bot::BasicBot::Pluggable::Module::store {
  $store ||= Bot::BasicBot::Pluggable::Store->new;
}

ok( my $ib = Bot::BasicBot::Pluggable::Module::Infobot->new );


# ok, the intent here is to test / document the infobot grammar, because
# every time I mess with it I get annoying regressions. In general, B::B::P
# wasn't built with Test-Driven techniques, and this is hurting me recently,
# it's way to hard to write tests retroactively..

ok( $ib->help, "module has help text" );

# by default, the infobot doesn't learn things that it merely overhears
ok( ! indirect("foo is red"), "passive learning off by default" );
ok( ! indirect("foo?"), "no answer to passive learn" );
is( direct("foo?"), "No clue. Sorry.", "no info on foo" );

# ..but it will learn things it's told directly.
is( direct("foo?"), "No clue. Sorry.", "no info on foo" );
is( direct("foo is red"), "ok", "active learning works" );
is( direct("foo?"), "foo is red", "correct answer to active learn" );
ok( !indirect("foo?"), "passive questioning off by default" );

# you can turn on the ability to ask questions without addressing the bot
ok( $ib->set("user_passive_ask", 1), "activate passive ask" );
is( indirect("foo?"), "foo is red", "passive questioning now on" );

# and the ability to add factoids without addressing the bot
ok( $ib->set("user_passive_learn", 1), "activate passive learn" );
is( direct("bar is green"), "ok", "passive learning now works" );
is( indirect("bar?"), "bar is green", "passive questioning works" );

# you can search factoids, but not in public
is( direct("search for foo"), "privmsg only, please", "not searched in public");
is( private("search for foo"), "Keys: 'foo'", "searched for 'foo'");

# you can append strings to factoids
is( direct("foo is also blue"), "ok", "can append to faactoids" );
is( direct("foo?"), "foo is red or blue", "works" );
is( direct("foo is also pink"), "ok", "can append to faactoids" );
is( direct("foo?"), "foo is red or blue or pink", "works" );

# factoids can be forgotten
is( direct("forget foo"), "I forgot about foo", "forgotten foo");
is( direct("foo?"), "No clue. Sorry.", "no info on foo" );

# factoids can be replaced
is( direct("bar is yellow"), "But I already know something about bar",
  "Can't just redefine factoids" );
is( indirect("bar?"), "bar is green", "not changed" );
is( direct("no, bar is yellow"), "ok", "Can explicitly redefine factoids" );
is( indirect("bar?"), "bar is yellow", "changed" );

# factoids can contain RSS
is( direct("rsstest is <rss=\"file://$Bin/test.rss\">"), "ok", "set RSS" );
is( indirect("rsstest?"), "rsstest is title;", "can read rss");

# certain things can't be factoid keys.
ok( $ib->set("user_stopwords", "and"), "set stopword 'and'" );
ok( !direct("and is mumu"), "can't set 'and' as factoid");
ok( !direct("dkjsdlfkdsjfglkdsfjglfkdjgldksfjglkdfjglds is mumu"),
  "can't set very long factoid");

# literal syntax
is( direct("literal rsstest?"), "rsstest =is= <rss=\"file://$Bin/test.rss\">",
  "literal of rsstest" );

ok( direct("bar is also fum"), "bar also fum" );
is( direct("literal bar?"), "bar =is= yellow =or= fum", "bar" );


# TODO - test alternate factoids ('|')




# utility functions

# tell the module something privately
sub private {
  my $message = {
    body => $_[0],
    who => "test_user",
    channel => "msg",
    address => 1,
  };
  return $ib->told($message) || $ib->fallback($message);
}

sub direct {
  my $message = {
    body => $_[0],
    who => "test_user",
    channel => "#test",
    address => 1,
  };
  return $ib->told($message) || $ib->fallback($message);
}

# the module has seen something
sub indirect {
  my $message = {
    body => $_[0],
    who => "test_user",
    channel => "#test",
    address => 0,
  };
  return $ib->told($message) || $ib->fallback($message);
}
