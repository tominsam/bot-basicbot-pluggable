#!perl
use warnings;
use strict;
use lib qw(lib t/lib);
use Test::More no_plan => 1;

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

# TODO - test infobot interactions
# TOOD - test active learning
# TOOD - test passive learning
# TODO - test active question answering
# TODO - test passive question answering
# TODO - test factoid searching
# TODO - test factoid appending
# TODO - test factoid deletion
# TODO - test factoid replacement
# TODO - test RSS
# TODO - test alternat factoids
# TODO - test stopwords
# TODO - test very long factoid keys
# TODO - test literal syntaax
