#!perl
use warnings;
use strict;
use Test::More tests => 6;

use FindBin qw( $Bin );
use lib $Bin;

use FakeBot;

my $title = load_module("Title");
ok($title, "loaded Title module");

like( say_direct("http://google.com"), qr/Google/, "got title of google ok" );

# test to make sure that Title.pm isn't eating urls.
ok(load_module("Infobot"), "loaded Infobot module");
my $t = say_direct("google is at http://google.com");
like($t, qr/Google/, "got title of google ok" );
like($t, qr/Okay/, "infobot still there" );

$title->set('user_ignore_re' => 'perl');
my $ig = say_direct("http://use.perl.org");
is ($ig, '', 'ignore_re works');
