=head1 NAME

Bot::BasicBot::Pluggable - extension to the simple irc bot base class
allowing for pluggable modules

=head1 SYNOPSIS

=head2 Creating the bot module

  # with all defaults
  my $bot = Bot::BasicBot->new();

  # with useful options
  my $bot = Bot::BasicBot::Pluggable->new( channels => ["#bottest"],

                      server => "irc.example.com",
                      port   => "6667",

                      nick     => "pluggabot",
                      altnicks => ["pbot", "pluggable"],
                      username => "bot",
                      name     => "Yet Another Pluggable Bot",

                      ignore_list => [qw(hitherto blech muttley)],

                );

  (You can pass any option that's valid for Bot::BasicBot)

=head2 Running the bot (simple)

There's a shell script installed to run the bot.

  $ bot-basicbot-pluggable.pl --nick MyBot --server irc.perl.org

Then connect to the IRC server, /query the bot, and set a password. See
L<Bot::BasicBot::Pluggable::Module::Auth> for details.

=head2 Running the bot (advanced)

There are two useful ways you can use a Pluggable bot. The simple way and the
flexible way. The simple way is:

  # Load some useful modules
  my $infobot_module = $bot->load("Infobot");
  my $google_module = $bot->load("Google");
  my $seen_module = $bot->load("Seen");

  # Set the google key (see http://www.google.com/apis/)
  $google_module->set("google_key", "some google key");
  
  $bot->run();

This lets you run a bot with a few modules, but not change those modules
during the run of the bot. The complex way is as follows:

  # Load the loader module
  $bot->load('Loader');
  
  # run the bot
  $bot->run();

This is simpler but needs setup once the bot is joined to a server. the Loader
module lets you talk to the bot in-channel and tell it to load and unload other
modules. The first one you'll want to load is the 'Auth' module, so that other
people can't load and unload modules without permission. Then you need to log in
as an admin and change your password.

  (in a query)
  !load Auth
  !auth admin julia
  !password julia new_password
  !auth admin new_password
  
Once you've done this, your bot is safe against other IRC users. Now you can tell
it to load and unload other modules any time:

  !load Seen
  !load Google
  !load Join

The join module lets you tell the bot to join and leave channels:

  !join #mychannel
  !leave #someotherchannel
  
The perldoc pages for the various modules will list other commands.


=head1 DESCRIPTION

Bot::BasicBot::Pluggable started as Yet Another Infobot replacement, but now
is a generalised framework for writing infobot-type bots, that lets you keep
each function seperate. You can have seperate modules for factoid tracking,
'seen' status, karma, googling, etc. Included with the package are modules
for:

  Auth - user authentication and admin access
  Loader - loads and unloads modules as bot commands
  Join - joins and leaves channels
  Vars - changes module variables
  Infobot - handles infobot-style factoids
  Karma - tracks the popularity of things
  Seen - tells you when people were last seen
  DNS - host lookup
  Google - search google for things
  Title - Gets the title of pages mentioned in channel

use perldoc Bot::BasicBot::Pluggable::Module::<module name> for help on
their terminology.

The way this works is very simple. You create a new bot object, and tell it
to load various modules. Then you run the bot. The modules get events when
the bot sees things happen, and can respond to the events.

perldoc Bot::BasicBot::Pluggable::Module::Base for the details of the module API.

=cut

package Bot::BasicBot::Pluggable;
use strict;
use warnings;

our $VERSION = '0.50';

use POE;
use Bot::BasicBot;
use base qw( Bot::BasicBot );

use Bot::BasicBot::Pluggable::Module;
use Bot::BasicBot::Pluggable::Store::Storable;
use Bot::BasicBot::Pluggable::Store::DBI;

sub init {
  my $self = shift;

  # the default store is a SQLite store
  $self->{store} ||= {
    type => "DBI",
    dsn => "dbi:SQLite:bot-basicbot.sqlite",
    table => "basicbot",
  };

  # calculate the class we're going to use. If you pass a full
  # classname as the type, use that class, otherwise assume it's
  # a B::B::Store:: subclass.
  my $store_class = delete $self->{store}{type} || "DBI";
  $store_class = "Bot::BasicBot::Pluggable::Store::$store_class"
    unless $store_class =~ /::/;

  # load the store class
  eval "require $store_class";
  die "Couldn't load $store_class - $@" if $@;

  $self->{store_object} ||= $store_class->new(%{$self->{store}});

  return 1;
}

=head2 Main Methods

=over 4

=item new

Create a new Bot. Identical to the new method in Bot::BasicBot.

=item load($module)

Load a module for the bot by name, from ./modules/Modulename.pm if that file
exists, and falling back to the system package
Bot::BasicBot::Pluggable::Module::$module if not.

=cut

sub load {
  my $self = shift;
  my $module = shift;

  # it's safe to die here, mostly this call is evaled
  die "Need name" unless $module;
  die "Already loaded" if $self->handler($module);

  # This is possible a leeeetle bit evil.
  print STDERR "Loading module '$module'.. ";
  my $file = "Bot/BasicBot/Pluggable/Module/$module.pm";
  $file = "./modules/$module.pm" if (-e "./modules/$module.pm");
  print STDERR "from file $file\n";
  
  # force a reload of the file (in the event that we've already loaded it)
  no warnings 'redefine';
  delete $INC{$file};
  require $file;
  # Ok, it's very evil. Don't bother me, I'm working.

  my $m = "Bot::BasicBot::Pluggable::Module::$module"->new(Bot=>$self, Param=>\@_);

  die "->new didn't return an object" unless ($m and ref($m));
  die ref($m)." isn't a $module" unless ref($m) =~ /\Q$module/;

  $self->add_handler($m, $module);

  return $m;
}

=item reload($module)

Reload the module $module - equivalent to unloading it (if it's already
loaded) and reloading it. Will stomp the old module's namespace - warnings
are expected here.

Not toally clean - if you're experiencing odd bugs, restart the bot if
possible. Works for minor bug fixes, etc.

=cut

sub reload {
  my $self = shift;
  my $module = shift;
  return "Need name" unless $module;
  $self->remove_handler($module) if $self->handler($module);
  return $self->load($module);
}

=item unload

Removes a module from the bot. It won't get events any more.

=cut

sub unload {
  my $self = shift;
  my $module = shift;
  return "Need name" unless $module;
  return "Not loaded" unless $self->handler($module);
  warn "Unloading module '$module'..\n";

  $self->remove_handler($module);
  return "Removed";
}

=item module($module)

returns the handler object for the loaded module '$module'. used, eg, to get
the 'Auth' hander to check if a given user is authenticated.

=cut

sub module {
  my $self = shift;
  return $self->handler(@_);
}    

=item modules

returns a list of the names of all loaded modules, as an array.

=cut

sub modules {
  my $self = shift;
  return $self->handlers(@_);
}

# deprecated methods
sub handler {
  my ($self, $name) = @_;
  return $self->{handlers}{lc($name)};
}

sub handlers {
  my $self = shift;
  my @keys = keys(%{$self->{handlers}});
  return @keys if wantarray;
  return \@keys;
}

=head2 add_handler(handler object, name of handler)

adds a handler object with the given name to the queue of modules. There
is no order specified internally, adding a module earlier does not
guarantee it gets called first. Names must be unique.

=cut

sub add_handler {
  my ($self, $handler, $name) = @_;
  die "Need a name for adding a handler" unless $name;
  die "Can't load a handler with a duplicate name $name" if $self->{handlers}{lc($name)};
  $self->{handlers}{lc($name)} = $handler;    
}

=head2 remove_handler

remove a handler with the given name.

=cut

sub remove_handler {
  my ($self, $name) = @_;
  die "Need a name for removing a handler" unless $name;
  die "Hander $name not defined" unless $self->{handlers}{lc($name)};
  delete $self->{handlers}{lc($name)};
  return "Done.";
}

=head2 store

returns the object store associated with the bot. See L<Bot::BasicBot::Pluggable::Store>.

=cut

sub store {
  my $self = shift;
  if (@_) {
    $self->{store} = shift;
    return $self;
  }
  return $self->{store_object};
}

####################################################
# ..from Bot::BasicBot:

=head2 dispatch(method name, params)

call the named method on every loaded module, if the module has a method
with that name.

=cut

sub dispatch {
  my $self = shift;
  my $method = shift;

  for my $who ($self->handlers) {
    next unless $self->handler($who)->can($method);
    eval "\$self->handler(\$who)->$method(\@_);";
    warn $@ if $@;
  }
  return undef;
}

sub tick {
  my $self = shift;
  $self->dispatch('tick');
  return 5;
}

=head2 said

called as a subclass of Bot::BasicBot, 

=cut

sub said {
  my $self = shift;
  my ($mess) = @_;
  my $response;
  my $who;
  
  for my $priority (0..3) {
    for ($self->handlers) {
      $who = $_;
      eval "\$response = \$self->handler(\$who)->said(\$mess, \$priority); ";
      $self->reply($mess, "Error calling said() for $who: $@") if $@;
      if ($response and $priority) {
        return if ($response eq "1");
        $self->reply($mess, $response);
        return;
      }
    }
  }
  return undef;
}

sub emoted {
  my $self = shift;
  my $mess = shift;
  my $response;
  my $who;
  
  for my $priority (0..3) {
    for ($self->handlers) {
      $who = $_;
      eval "\$response = \$self->handler(\$who)->emoted(\$mess, \$priority); ";
      $self->reply($mess, "Error calling emoted() for $who: $@") if $@;
      if ($response and $priority) {
        return if ($response eq "1");
        $self->reply($mess, $response);
        return;
      }
    }
  }
  return undef;
}

sub help {
  my $self = shift;
  my $mess = shift;
  $mess->{body} =~ s/^help\s*//i;
  
  unless ($mess->{body}) {
    return "Ask me for help about: " . join(", ", $self->handlers())." (say 'help <modulename>')";
  } else {
    if (my $handler = $self->handler($mess->{body})) {
      my $help;
      eval "\$help = \$handler->help(\$mess); ";
      return "Error calling help for handler $mess->{body}: $@" if $@;
      return $help;
    } else {
      return "I don't know anything about '$mess->{body}'.";
    }
  }
}

sub connected {
  my $self = shift;
  warn "Bot::BasicBot::Pluggable connected\n";
  $self->dispatch('connected');
}

sub chanjoin {
  shift->dispatch("chanjoin", @_);
}

sub chanpart {
  shift->dispatch("chanpart", @_);
}

=item run

runs the bot. The POE core gets control as of this point, you're unlikely to
get control back.

=back

=head1 AUTHOR

Tom Insam E<lt>tom@jerakeen.orgE<gt>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 CREDITS

Bot::BasicBot was written initially by Mark Fowler, and worked on heavily by
Simon Kent, who was kind enough to apply some patches I needed for
Pluggable.

Eventually.

Oh, yeah, and I stole huge chunks of docs from the Bot::BasicBot source,
too.

Various people helped with modules. Convert was almost ported from the
infobot code by blech. But not quite. Thanks for trying.. blech has also put
a lot of effort into the chump.cgi/chump.tem in the examples/ folder,
including some /inspired/ calendar evilness.

And thanks to the rest of #2lmc, who were my unwilling guinea pigs during
development. And who kept suggesting totally stupid ideas for modules that I
then felt compelled to go implement. Shout.pm owes it's existence to #2lmc.

I spent a lot of time in the mozbot code, and that has influenced my ideas
for Pluggable. Mostly to get round its awfulness.

=head1 SYSTEM REQUIREMENTS

Bot::BasicBot::Pluggable is based on POE, and really needs the latest
version. Because POE is like that sometimes.

You also need POE::Component::IRC. Oh, and Bot::BasicBot.

Some of the modules will need more modules. eg, Google.pm needs Net::Google.
See the module docs for more details.

=head1 BUGS

During the make, make test make install process, POE will moan about
its kernel not being run. This is a Bot::BasicBot problem, apparently.

reloading a module causes warnings as the old module gets it's namespace
stomped. Not a lot you can do about that.

All modules need to be in the Bot::Pluggable::Module:: namespace. Well,
that's not really a bug.                                                                                       

More other things than I can shake a stick at.

=head1 SEE ALSO

POE

POE::Component::IRC

Bot::BasicBot

Possibly Infobot, at http://www.infobot.org, and Mozbot, somewhere in mozilla.org.

=cut

1; # sigh.

