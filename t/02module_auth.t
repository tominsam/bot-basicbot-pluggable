#!/usr/bin/perl
use warnings;
use strict;
use lib qw(./lib);

use Test::More tests => 18;

use Bot::BasicBot::Pluggable;
use Bot::BasicBot::Pluggable::Module::Auth;

our $store;
no warnings 'redefine';
sub Bot::BasicBot::Pluggable::Module::store {
  $store ||= Bot::BasicBot::Pluggable::Store->new;
}

ok(my $auth = Bot::BasicBot::Pluggable::Module::Auth->new(), "created auth module");

ok(!$auth->authed('bob'), "bob not authed yet");
ok(command("!auth admin muppet"), "sent bad login");
ok(!$auth->authed('bob'), "bob not authed yet");
ok(command("!auth admin julia"), "sent good login");
ok($auth->authed('bob'), "bob authed now");

ok(command("!adduser bob bob"), "added bob user");
ok(command("!auth bob fred"), "not logged in as bob");
ok(!$auth->authed('bob'), "not still authed");
ok(command("!auth bob bob"), "logged in as bob");
ok($auth->authed('bob'), "still authed");

ok(command("!deluser admin"), "deleted admin user");
ok(command("!auth admin julia"), "tried login");
ok(!$auth->authed('bob'), "not authed");

ok(command("!auth bob bob"), "logged in as bob");
ok(command("!passwd bob dave"), "changed password");
ok(command("!auth bob dave"), "tried login");
ok($auth->authed('bob'), "authed");

sub command {
  my $body = shift;
  my $response = $auth->said( {
    address => 1, body => $body, who => 'bob'
  }, 1 );
  #warn "$response\n";
  return $response;
}
