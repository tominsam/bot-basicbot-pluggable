=head1 NAME

Bot::BasicBot::Pluggable::Module

=head1 SYNOPSIS

The base module for all Bot::BasicBot::Pluggable modules. Inherit from this
to get all sorts of exciting things.

=head1 IRC INTERFACE

There isn't one - the 'real' modules inherit from this one.

=head1 MODULE INTERFACE

You MUST override the 'said' and the 'help' methods. help() MUST return
the help text for the module.

You MAY override the 'chanjoin', 'chanpart', and 'tick' methods. the said()
method MAY return a response to the event.

=head1 OBJECT STORE

Every pluggable module gets an object store to save variables in. Access
this store using the seg() and set() accessors, ie

  my $count = $self->get("count");
  $self->set( count => $count + 1 );

Do not access the store through any other means - the location of the
store, and it's method of storage, may change at any time.

Keys that begin "user_" should be considered _USER_ variables, and can be
changed be people with admin access in the IRC channel, using
L<Bot::BasicBot::Pluggable::Module::Vars>. Don't use them as unchecked
input data.

Implementation detail - TODO - describe this. Fast summary - try not to
put things that aren't scalars in the object store.

=head1 METHODS

=cut

package Bot::BasicBot::Pluggable::Module;
use strict;
use warnings;

=head2 new()

Standard new method, blesses a hash into the right class and puts any
key/value pairs passed to it into the blessed hash. Calls load() to load
any internal variables, then init(), which you should override in your
module.

=cut

sub new {
    my $class = shift;
    my %param = @_;

    my $name = ref($class) || $class;
    $name =~ s/^.*:://;
    $param{Name} ||= $name;

    my $self = \%param;
    bless $self, $class;

    $self->init();

    return $self;
}

=head2 bot()

returns the Bot::BasicBot::Pluggable bot we're running under

=cut

sub bot {
    my $self = shift;
    return $self->{Bot};
}

=head2 store()

returns the Bot::BasicBot::Pluggable::Store subclass that the bot is
using to store it's variables.

=cut

sub store {
  my $self = shift;
  die "module has no bot" unless $self->bot;
  return $self->bot->store;
}

=head2 var( name, [ value ] )

get or set a local variable from the module store

=cut

sub var {
    my $self = shift;
    my $name = shift;
    if (@_) {
        return $self->set($name, shift);
    } else {
        return $self->get($name);
    }
}

=head2 set( name => value )

set a local variable into the object store.

=cut

sub set {
    my $self = shift;
    $self->store->set($self->{Name}, @_);
}

=head2 get( name )

returns the value of a local variable from the object store.

=cut

sub get {
    my $self = shift;
    $self->store->get($self->{Name}, @_);
}

=head2 unset(var)

unsets a local variable - removes it from the store, not just undefs it.

=cut

sub unset {
    my $self = shift;
    $self->store->unset($self->{Name}, @_);
}

=head2 store_keys()

returns a list of all keys in the object store

=cut

sub store_keys {
    my $self = shift;
    $self->store->keys($self->{Name}, @_);
}

=head2 say(message)

passing through to the underlying Bot::BasicBot object, this method lets
you send messages without replying to a said() call, eg:

  $self->say({ who => 'tom', body => 'boo', channel => 'msg' });

=cut

sub say {
  my $self = shift;
  return $self->{Bot}->say(@_);
}

=head2 reply(message, body)

replies to the given message with the given text. Another passthrough to the
Bot::BasicBot object. The message is used to pre-populate the reply, so it'll
be in the same channel as the question, directed to the right user, etc.

=cut

sub reply {
  my $self = shift;
  return $self->{Bot}->reply(@_);
}

=head2 tell(nick / channel, message)

convenience method to send a message to the given nick or channel, will send
a privmsg if a nick is given, or a public for a channel.

  $self->tell('tom', "hello there, fool");

or

  $self->tell('#sailors', "hello there, sailor");

=cut

sub tell {
  my $self = shift;
  my $target = shift;
  my $body = shift;
  if ($target =~ /^#/) {
    $self->say({ channel => $target, body => $body });
  } else {
    $self->say({ channel => 'msg', body => $body, who => $target });
  }
}

=head2 said(message, priority)

This is I<the> method to override. It's called when the bot sees
something said. The first parameter is a Bot::BasicBot 'message' object,
as passed to it's 'said' function - see the Bot::BasicBot docs for
details. The second parameter is the priority of the message - all
modules will have the 'said' function called up to 4 times, with a
priority of 0, then 1, then 2, then 3. The first module to return a
non-null value 'claims' the message, and the bot will reply to it with
the value returned.

The exception to this is the '0' priority, which a module MUST NOT
respond to. This is so that all modules will at least see all messages.

I suggest a method like:

  sub said {
    my ($self, $mess, $pri) = @_;
    my $body = $mess->{body};

    return unless ($pri == 2); # most common

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);

    # do something here

    return;
  }

Optionally, you can not override this method, and override one of the
seperate seen(), admin(), told() and fallback() methods, corresponding
to priorities 0, 1, 2 and 3 in order - this is much preferred, and will
lead to nicer code. It's very new, though, which is why it's not used
in most of the shipped moduels yet. It will eventually become the only thing
to do, and I will deprecate said()

=cut

sub said {
  my ($self, $mess, $pri) = @_;
  $mess->{body} =~ s/\s+$//;
  $mess->{body} =~ s/^\s+//;
  
  if ($pri == 0) {
    return $self->seen($mess);
  } elsif ($pri == 1) {
    return $self->admin($mess);
  } elsif ($pri == 2) {
    return $self->told($mess);
  } elsif ($pri == 3) {
    return $self->fallback($mess);
  }
  return undef;
}

=head2 seen(mess)

Like said(), called if you don't override said, but only for priority 0.

=cut

sub seen { undef }

=head2 admin(mess)

Like said(), called if you don't override said, but only for priority 1.

=cut

sub admin { undef }

=head2 seen(mess)

Like said(), called if you don't override said, but only for priority 2.

=cut

sub told { undef }

=head2 fallback(mess)

Like said(), called if you don't override said, but only for priority 3.

=cut

sub fallback { undef }


=head2 connected

called when the bot connects to the server. The return value is meaningless.

=cut

sub connected { undef }

=head2 init

called when the module is created, and after the settings are loaded.
This may or may not be after the bot has connected to the server - make
no assumptions.

=cut

sub init { undef }

=head2 help

Called when a user asks for help on a topic. Should return some useful
help text. For Bot::BasicBot::Pluggable, when a user asks the bot
'help', the bot will return a list of modules. Asking the bot 'help
<modulename>' will call the help function of that module, passing in the
first parameter the message object that represents the question.

=cut

sub help {
    my ($self, $mess) = @_;
    return "No help for module '$self->{Name}'. This is a bug.";
}

=head2 emoted($mess, $priority)

called when a user emotes something in channel. Params are the same as those
passed to said(), and the semantics as regards returning are identical as
well.

=cut

sub emoted { undef }

=head2 tick()

the tick event. The method is called every 5 seconds. It's probably
worth having a counter and not responding to every single one, assuming
you want to respond to it at all. The return value is ignored.

=cut

sub tick { undef }

=head2 chanjoin($mess)

called when a user joins a channel. $mess is the event described in
L<Bot::BasicBot>, it's a hashref, the important keys are:

=over 4

=item who

the nick of the joining user

=item channel

the channel they joined

=back

=cut

sub chanjoin { undef }

=head2 chanpart($mess)

called when a user leaves a channel. Passed the same structure as the
chanjoin method is.

=cut

sub chanpart { undef }

1;
