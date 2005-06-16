package FakeBot;
use warnings;
use strict;
use base qw( Exporter );
use Bot::BasicBot::Pluggable;

our @EXPORT = qw( load_module say_private say_direct say_indirect $basicbot );

our $basicbot = Bot::BasicBot::Pluggable->new(
  store_object => Bot::BasicBot::Pluggable::Store->new,
);

my $reply = [];

sub load_module { $basicbot->load(@_) }

# tell the module something privately
sub say_private {
  my $message = {
    body => $_[0],
    who => "test_user",
    channel => "msg",
    address => 1,
    reply_hook => \&catch,
  };
  $reply = [];
  $basicbot->said($message);
  return join "\n",@$reply;
}

sub say_direct {
  my $message = {
    body => $_[0],
    who => "test_user",
    channel => "#test",
    address => 1,
    reply_hook => \&catch,
  };
  $reply = [];
  $basicbot->said($message);
  return join "\n",@$reply;
}

# the module has seen something
sub say_indirect {
  my $message = {
    body => $_[0],
    who => "test_user",
    channel => "#test",
    address => 0,
    reply_hook => \&catch,
  };
  $reply = [];
  $basicbot->said($message);
  return join "\n",@$reply;
}


sub catch {
  my $mess = shift;
  # record the reply;
  push @$reply, @_;
}
