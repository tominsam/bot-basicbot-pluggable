#!/usr/bin/perl
use warnings;
use strict;

use Test::More tests => 18;
use Test::Bot::BasicBot::Pluggable;

my $bot = Test::Bot::BasicBot::Pluggable->new();

ok(my $auth = $bot->load('Auth'), "created auth module");

ok(!$auth->authed('test_user'), "test_user not authed yet");
ok($bot->tell_private("!auth admin muppet"), "sent bad login");
ok(!$auth->authed('test_user'), "test_user not authed yet");
ok($bot->tell_private("!auth admin julia"), "sent good login");
ok($auth->authed('test_user'), "test_user authed now");

ok($bot->tell_private("!adduser test_user test_user"), "added test_user user");
ok($bot->tell_private("!auth test_user fred"), "not logged in as test_user");
ok(!$auth->authed('test_user'), "not still authed");
ok($bot->tell_private("!auth test_user test_user"), "logged in as test_user");
ok($auth->authed('test_user'), "still authed");

ok($bot->tell_private("!deluser admin"), "deleted admin user");
ok($bot->tell_private("!auth admin julia"), "tried login");
ok(!$auth->authed('test_user'), "not authed");

ok($bot->tell_private("!auth test_user test_user"), "logged in as test_user");
ok($bot->tell_private("!passwd test_user dave"), "changed password");
ok($bot->tell_private("!auth test_user dave"), "tried login");
ok($auth->authed('test_user'), "authed");
