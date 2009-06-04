#!perl
use warnings;
use strict;
use lib qw(lib t/lib);
use Test::More tests => 84;

use FindBin qw( $Bin );
use lib $Bin;

# this one is a complete bugger to build
eval "use XML::Feed";
our $HAS_XML_FEED = $@ ? 0 : 1;

use FakeBot;

ok( my $ib = load_module("Infobot"), "Loaded infobot module");

ok( my $uur = $ib->get("user_unknown_responses") , "got list of unknown responses") or die;
my $no_regex = qr/($uur)/;

# ok, the intent here is to test / document the infobot grammar, because
# every time I mess with it I get annoying regressions. In general, B::B::P
# wasn't built with Test-Driven techniques, and this is hurting me recently,
# it's way too hard to write tests retroactively..

ok( $ib->help, "module has help text" );

# by default, the infobot doesn't learn things that it merely overhears
ok( ! say_indirect("foo is red"), "passive learning off by default" );
ok( ! say_indirect("foo?"), "no answer to passive learn" );
like( say_direct("foo?"), $no_regex, "no info on foo" );

# ..but it will learn things it's told say_directly.
like( say_direct("foo?"), $no_regex, "no info on foo" );
is( say_direct("foo is red"), "Okay.", "active learning works" );
is( say_direct("foo?"), "foo is red", "correct answer to active learn" );

like( say_direct("quux?"), $no_regex, "no info on quux" );
is( say_direct("quux are blue"), "Okay.", "active learning works" );
is( say_direct("quux?"), "quux are blue", "correct answer to active learn" );


ok( !say_indirect("foo?"), "passive questioning off by default" );

# you can turn on the ability to ask questions without addressing the bot
ok( $ib->set("user_passive_answer", 1), "activate passive ask" );
is( say_indirect("foo?"), "foo is red", "passive questioning now on" );

# and the ability to add factoids without addressing the bot
ok( $ib->set("user_passive_learn", 1), "activate passive learn" );
is( say_direct("bar is green"), "Okay.", "passive learning now works" );
is( say_indirect("bar?"), "bar is green", "passive questioning works" );

# you can search factoids, but not in public
is( say_direct("search for foo"), "privmsg only, please", "not searched in public");
$ib->set("user_allow_searching",0);
is( say_private("search for foo"), "searching disabled", "searched for 'foo' disabled");
$ib->set("user_allow_searching",1);
is( say_private("search for foo"), "I know about: 'foo'.", "searched for 'foo'");

# you can append strings to factoids
is( say_direct("foo is also blue"), "Okay.", "can append to faactoids" );
is( say_direct("foo?"), "foo is red or blue", "works" );
is( say_direct("foo is also pink"), "Okay.", "can append to faactoids" );
is( say_direct("foo?"), "foo is red or blue or pink", "works" );

# factoids can be forgotten
is( say_direct("forget foo"), "I forgot about foo.", "forgotten foo");
like( say_direct("foo?"), $no_regex, "no info on foo" );

# factoids can be replaced
my $but_reply = '... but bar is green ...'; # ok, why does this get interpreted as '1'
is( say_direct("bar is yellow"), $but_reply,
  "Can't just redefine factoids" );
is( say_indirect("bar is yellow"), '',
  "Can't just redefine factoids" );
is( say_indirect("bar?"), "bar is green", "not changed" );
is( say_direct("no, bar is yellow"), "Okay.", "Can explicitly redefine factoids" );
is( say_indirect("bar?"), "bar is yellow", "changed" );

# factoids can contain RSS
{ local $TODO = !$HAS_XML_FEED;
is( say_direct("rsstest is <rss=\"file://$Bin/test.rss\">"), "Okay.", "set RSS" );
is( say_indirect("rsstest?"), "title", "can read rss");

say_direct("rsstest2 is <rss=\"file://$Bin/infobot.t\">");
like( say_indirect("rsstest2?"), qr{rsstest2 is << Error parsing RSS from file:///.*/infobot.t: Cannot detect feed type >>}, "can't read rss");
}



my $old_stopwords = $ib->get("user_stopwords");

# certain things can't be factoid keys.
ok( $ib->set("user_stopwords", "and"), "set stopword 'and'" );
ok( !say_direct("and is mumu"), "can't set 'and' as factoid");
ok( !say_direct("dkjsdlfkdsjfglkdsfjglfkdjgldksfjglkdfjglds is mumu"),
  "can't set very long factoid");

$ib->set("user_stopwords", $old_stopwords);

# literal syntax
is( say_direct("literal rsstest?"), "rsstest =is= <rss=\"file://$Bin/test.rss\">",
  "literal of rsstest" );
ok( say_direct("bar is also fum"), "bar also fum" );
is( say_direct("literal bar?"), "bar =is= yellow =or= fum", "bar" );


# alternate factoids ('|')
is( say_direct("foo is one"), "Okay.", "foo is one");
is( say_direct("foo is also two"), "Okay.", "foo is also two");
is( say_direct("foo is also |maybe"), "Okay.", "foo is also maybe");

ok( my $reply = say_direct("foo?"), "got one of the foos" );
ok( ( $reply eq 'foo is maybe' or $reply eq 'foo is one or two' ), "it's one of the two");

# blech's torture test, all three in one
# notes on dipsy differences:
# * 'ok' is 'okay.' in a true infobot
# * literal doesn't highlight =or= like it does =is=
# * infobots attempt to parse english
# * there's a difference between 'is' and 'are'
# * doesn't respond to a passive attempt to reset an item

is( say_direct("forget foo"), "I forgot about foo.", "forgotten foo");

is( say_direct("foo is foo"), "Okay.", "simple set" );
is( say_direct("foo?"), "foo is foo", "simple get" );
is( say_direct("what is foo?"), "foo is foo", "English-language get" ); # fails
is( say_direct("where is foo?"), "foo is foo", "Another English get" );
is( say_direct("who is foo?"), "foo is foo", "Yet another English get" );

is( say_direct("hoogas are things"), "Okay.", "simple 'are' set"); # fails
is( say_direct("what are hoogas?"), "hoogas are things", "English-language 'are' get" );

is( say_direct("foo is a silly thing"), "... but foo is foo ...", "warning about overwriting" );
is( say_indirect("foo is a silly thing"), "", "shouldn't get a reply" );

is( say_direct("foo is also bar"), "Okay.", "simple append");
is( say_direct("foo?"), "foo is foo or bar", "appended ok");
is( say_direct("foo is also baz or quux"), "Okay.", "complex append");
is( say_direct("foo?"), "foo is foo or bar or baz or quux", "also ok");
is( say_direct("foo is also | a silly thing"), "Okay.", "alternate appended");

is( say_direct("literal foo?"), 
           "foo =is= foo =or= bar =or= baz =or= quux =or= |a silly thing", 
           "entire factoid looks right");
is( say_direct("foo is also |<reply>this is a very silly thing"), "Okay.", "and a reply");
is( say_direct("literal foo?"), 
           "foo =is= foo =or= bar =or= baz =or= quux =or= |a silly thing =or= |<reply>this is a very silly thing", 
           "entire entry looks fine to me");

# run through a few times, and see what we get out
foreach my $i (0..9) {
  ok( $reply = say_direct("foo?"), "got one of the foos" );
  ok( ( $reply eq 'foo is foo or bar or baz or quux'
   or $reply eq 'foo is a silly thing' 
   or $reply eq 'this is a very silly thing' ),
                "it's '$reply'"
  );
}
