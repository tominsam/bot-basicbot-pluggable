=head1 NAME

Bot::BasicBot::Pluggable::Module::Base

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

The bot has a local hash, $self->{store}, that is saved and loaded when the bot
quits and starts. The variables are accessed through the get() and set() methods
(or the var() method), and the store is automatically saved after every set
call, but if you change the store in any other way, I suggest you explicitly
save it with the save() method.

=head1 BUGS

The {store} isn't any good for /big/ data sets, like the infobot sets. We
need a better solution, probably involving Tie.

=head1 METHODS

=cut

package Bot::BasicBot::Pluggable::Module::Base;

use Storable;

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

    $self->load();
    $self->init();

    return $self;
}

=head2 var(name, [ value ])

get or set a local variable.

=cut

sub var {
    my $self = shift;
    my $name = shift;
    my $set = shift;
    if (defined($set)) {
        $self->set($name, $set);
        return $self;
    } else {
        return $self->get($name);
    }
}

=head2 set(var, name)

set a local variable to a value

=cut

sub set {
    my ($self, $name, $val) = @_;
    $self->{store}{vars}{$name} = $val;
    $self->save();
    return $self->{store}{vars}{$name};
}

=head2 get(var)

returns the value of a local variable

=cut

sub get {
    my ($self, $name) = @_;
    return $self->{store}{vars}{$name};
}

=head2 unset(var)

unsets a local variable - removes it from the store, not just undefs it.

=cut

sub unset {
    my ($self, $name) = @_;
    delete $self->{store}{vars}{$name};
    $self->save();
}

=head2 save

Saves the local data store. Just a simple implementation using Storable.
It's possible to override this if you need special behaviour.

=cut

sub save {
    my ($self, $hash, $filename) = @_;
    $filename ||= $self->{Name}.".storable";
    my $save = $hash || $self->{store};
    return unless $save;
    store($save, $filename) or die "cannot save to $filename";
}

=head2 load

loads the local store from the Storable file.

=cut

sub load {
    my ($self) = @_;
    my $filename = $self->{Name}.".storable";
    return unless (-e $filename);
    $self->{store} = retrieve $filename;
    return $self->{store};
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

=cut

sub said { undef }

=head2 connected

called when the bot connects to the server

=cut

sub connected { undef }

=head2 init

called when the module is created, and after the settings are loaded.
This may or may not be after the bot has connected to the server - make
no assumptions.

=cut

sub init { 1 }

=head2 help

Called when a user asks for help on a topic. Should return some useful
help text. For Bot::BasicBot::Pluggable, when a user asks the bot
'help', the bot will return a list of modules. Asking the bot 'help
<modulename>' will call the help function of that module, passing in the
first parameter the message object that represents the question.

=cut

sub help {
    my ($self, $mess) = @_;
    return "No help for: $self->{Name}. This is a bug.";
}

=head2 emoted($mess, $priority)

called when a user emotes something in channel. Params are the same as those
passed to said(), and the semantics as regards returning are identical as
well.

=cut

sub emoted { undef }

=head2 tick()

the tick event. All modules can have a regulat tick event called. By default,
this method is called 5 seconds after the module starts

have this called every 5 seconds. It's
probably worth having a counter and not responding to every single one,
assuming you want to respond to it at all.

=cut

sub tick { undef }

=head2 schedule_tick(time)

Causes the C<tick> event to be called in 'time' seconds (or 5 seconds if
time is left unspecified). Note that if the tick event is due to be
called already, this will override it, you can't schedule multiple
future events with this funtction.

=cut

sub schedule_tick {
  my $self = shift;
  my $time = shift || 5;
#  $self->{Bot}{kernel}->delay( "tick_$self->{Name}" => $time );
}


=cut

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
