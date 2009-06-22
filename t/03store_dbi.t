#!perl
use warnings;
use strict;
use Test::Bot::BasicBot::Pluggable::Store;

use File::Temp qw(tempfile);
my ($fh,$tempfile) = tempfile( UNLINK => 1 );

store_ok('DBI',{ dsn => "dbi:SQLite:$tempfile", table => "basicbot" });
