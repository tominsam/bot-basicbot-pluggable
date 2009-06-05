package Test::Bot::BasicBot::Pluggable;
use warnings;
use strict;
use base qw( Bot::BasicBot::Pluggable );

sub new {
	my($class,%args) = @_;
	my $bot = $class->SUPER::new(
		store_object => Bot::BasicBot::Pluggable::Store->new,
  		nick => 'test_bot',
		%args
	);
	return bless $bot, $class;
}

sub tell_private  { shift->tell(shift,1,1) } # tell the module something privately
sub tell_direct   { shift->tell(shift,0,1) }
sub tell_indirect { shift->tell(shift,0,0) } # the module has seen something

sub tell {
  my ($bot,$body,$private,$addressed) = @_;
  my @reply;
  my $message = {
    body => $body,
    who => 'test_user',
    channel => $private ? 'msg' : '#test',
    address => $addressed,
    reply_hook => sub { push @reply, $_[1]; }, # $_[1] is the reply text
  };
  $bot->said($message);
  return join "\n", @reply;
}

# otherwise AUTOLOAD in Bot::BasicBot will be called
sub DESTROY {};

1;
