=head1 NAME

Bot::BasicBot::Pluggable - extended simple IRC bot for pluggable modules

=head1 SYNOPSIS

=head2 Creating the bot module

  # with all defaults.
  my $bot = Bot::BasicBot->new();

  # with useful options. pass any option
  # that's valid for Bot::BasicBot.
  my $bot = Bot::BasicBot::Pluggable->new(
  
                      channels => ["#bottest"],
                      server   => "irc.example.com",
                      port     => "6667",

                      nick     => "pluggabot",
                      altnicks => ["pbot", "pluggable"],
                      username => "bot",
                      name     => "Yet Another Pluggable Bot",

                      ignore_list => [qw(hitherto blech muttley)],

                );

=head2 Running the bot (simple)

There's a shell script installed to run the bot.

  $ bot-basicbot-pluggable.pl --nick MyBot --server irc.perl.org

Then connect to the IRC server, /query the bot, and set a password. See
L<Bot::BasicBot::Pluggable::Module::Auth> for further details.

=head2 Running the bot (advanced)

There are two useful ways to create a Pluggable bot. The simple way is:

  # Load some useful modules.
  my $infobot_module = $bot->load("Infobot");
  my $google_module = $bot->load("Google");
  my $seen_module = $bot->load("Seen");

  # Set the Google key (see http://www.google.com/apis/).
  $google_module->set("google_key", "some google key");

  $bot->run();

The above lets you run a bot with a few modules, but not change those modules
during the run of the bot. The complex, but more flexible, way is as follows:

  # Load the Loader module.
  $bot->load('Loader');

  # run the bot.
  $bot->run();

This is simpler but needs further setup once the bot is joined to a server. The
Loader module lets you talk to the bot in-channel and tell it to load and unload
other modules. The first one you'll want to load is the 'Auth' module, so that
other people can't load and unload modules without permission. Then you'll need
to log in as an admin and change the default password, per the following /query:

  !load Auth
  !auth admin julia
  !password julia new_password
  !auth admin new_password

Once you've done this, your bot is safe from other IRC users, and you can tell
it to load and unload other installed modules at any time. Further information
on module loading is in L<Bot::BasicBot::Pluggable::Module::Loader>.

  !load Seen
  !load Google
  !load Join

The Join module lets you tell the bot to join and leave channels:

  <botname>, join #mychannel
  <botname>, leave #someotherchannel

The perldoc pages for the various modules will list other commands.

=head1 DESCRIPTION

Bot::BasicBot::Pluggable started as Yet Another Infobot replacement, but now
is a generalised framework for writing infobot-type bots that lets you keep
each specific function seperate. You can have seperate modules for factoid
tracking, 'seen' status, karma, googling, etc. Included default modules are
below. Use C<perldoc Bot::BasicBot::Pluggable::Module::<module name>> for help
on their individual terminology.

  Auth    - user authentication and admin access.
  DNS     - host lookup (e.g. nslookup and dns).
  Google  - search Google for things.
  Infobot - handles infobot-style factoids.
  Join    - joins and leaves channels.
  Karma   - tracks the popularity of things.
  Loader  - loads and unloads modules as bot commands.
  Seen    - tells you when people were last seen.
  Title   - gets the title of URLs mentioned in channel.
  Vars    - changes module variables.

The way the Pluggable bot works is very simple. You create a new bot object
and tell it to load various modules (or, alternatively, load just the Loader
module and then interactively load modules via an IRC /query). The modules
receive events when the bot sees things happen and can, in turn, respond. See
C<perldoc Bot::BasicBot::Pluggable::Module> for the details of the module API.

=cut

package Bot::BasicBot::Pluggable;
use warnings;
use strict;

our $VERSION = '0.71';

use POE;
use Bot::BasicBot;
use base qw( Bot::BasicBot );

use Module::Pluggable sub_name => '_available', search_path => 'Bot::BasicBot::Pluggable::Module';
use Bot::BasicBot::Pluggable::Module;
use Bot::BasicBot::Pluggable::Store::Storable;
use Bot::BasicBot::Pluggable::Store::DBI;

sub init {
  my $self = shift;

  unless ($self->store) {

    # the default store is a SQLite store
    $self->store( {
      type  => "DBI",
      dsn   => "dbi:SQLite:bot-basicbot.sqlite",
      table => "basicbot",
    } );
  }
  $self->store_from_hashref($self->store) unless UNIVERSAL::isa($self->store, "Bot::BasicBot::Pluggable::Store");
  
  return 1;
}


sub store_from_hashref {
    my ($self, $store) = @_;
    # calculate the class we're going to use. If you pass a full
    # classname as the type, use that class, otherwise assume it's
    # a B::B::Store:: subclass.
    my $store_class = delete $store->{type} || "DBI";
    $store_class = "Bot::BasicBot::Pluggable::Store::$store_class"
      unless $store_class =~ /::/;

    # load the store class
    eval "require $store_class";
    die "Couldn't load $store_class - $@" if $@;

    print STDERR "Loading $store_class\n" if $self->{verbose};
    $self->store( $store_class->new(%{$store}) );
    die "Couldn't init a $store_class store\n" unless $self->store;

    $self->store;

}

=head1 METHODS

=over 4

=item new(key => value, ...)

Create a new Bot. Identical to the C<new> method in L<Bot::BasicBot>.

=item load($module)

Load a module for the bot by name from C<./ModuleName.pm> or
C<./modules/ModuleName.pm> in that order if one of these files
exist, and falling back to C<Bot::BasicBot::Pluggable::Module::$module>
if not.

=cut

sub load {
  my $self = shift;
  my $module = shift;

  # it's safe to die here, mostly this call is eval'd.
  die "Need name" unless $module;
  die "Already loaded" if $self->handler($module);

  # This is possible a leeeetle bit evil.
  print STDERR "Loading module '$module' " if $self->{verbose};
  my $file = "Bot/BasicBot/Pluggable/Module/$module.pm";
  $file = "./$module.pm" if (-e "./$module.pm");
  $file = "./modules/$module.pm" if (-e "./modules/$module.pm");
  print STDERR "from file $file.\n" if $self->{verbose};

  # force a reload of the file (in the event that we've already loaded it).
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

Reload the module C<$module> - equivalent to unloading it (if it's already
loaded) and reloading it. Will stomp the old module's namespace - warnings
are expected here. Not toally clean - if you're experiencing odd bugs, restart
the bot if possible. Works for minor bug fixes, etc.

=cut

sub reload {
  my $self = shift;
  my $module = shift;
  return "Need name" unless $module;
  $self->remove_handler($module) if $self->handler($module);
  return $self->load($module);
}

=item unload($module)

Removes a module from the bot. It won't get events any more.

=cut

sub unload {
  my $self = shift;
  my $module = shift;
  return "Need name" unless $module;
  return "Not loaded" unless $self->handler($module);
  warn "Unloading module '$module' ";
  $self->remove_handler($module);
}

=item module($module)

Returns the handler object for the loaded module C<$module>. Used, e.g.,
to get the 'Auth' hander to check if a given user is authenticated.

=cut

sub module {
  my $self = shift;
  return $self->handler(@_);
}

=item modules

Returns a list of the names of all loaded modules as an array.

=cut

sub modules {
  my $self = shift;
  return $self->handlers(@_);
}

=item available_modules

Returns a list of all available modules whether loaded or not

=cut

sub available_modules {
  my $self = shift;
  return sort map { s/^Bot::BasicBot::Pluggable::Module:://; $_ } $self->_available;
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

=item add_handler($handler_object, $handler_name)

Adds a handler object with the given name to the queue of modules. There
is no order specified internally, so adding a module earlier does not
guarantee it'll get called first. Names must be unique.

=cut

sub add_handler {
  my ($self, $handler, $name) = @_;
  die "Need a name for adding a handler" unless $name;
  die "Can't load a handler with a duplicate name $name" if $self->{handlers}{lc($name)};
  $self->{handlers}{lc($name)} = $handler;
}

=item remove_handler($handler_name)

Remove a handler with the given name.

=cut

sub remove_handler {
  my ($self, $name) = @_;
  die "Need a name for removing a handler" unless $name;
  die "Hander $name not defined" unless $self->{handlers}{lc($name)};
  $self->{handlers}{lc($name)}->stop();
  delete $self->{handlers}{lc($name)};
}

=item store

Returns the bot's object store; see L<Bot::BasicBot::Pluggable::Store>.

=cut

sub store {
  my $self = shift;
  if (@_) {
    $self->{store_object} = shift;
    return $self;
  }
  return $self->{store_object};
}

=item dispatch($method_name, $method_params)

Call the named C<$method> on every loaded module with that method name.

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

=item help

Returns help for the ModuleName of message 'help ModuleName'. If no message
has been passed, return a list of all possible handlers to return help for.

=cut

sub help {
  my $self = shift;
  my $mess = shift;
  $mess->{body} =~ s/^help\s*//i;
  
  unless ($mess->{body}) {
    return "Ask me for help about: " . join(", ", $self->handlers())." (say 'help <modulename>').";
  } elsif ($mess->{body} eq 'modules') { 
    return "These modules are available for loading: ".join(", ", $self->available_modules);
  } else {
    if (my $handler = $self->handler($mess->{body})) {
      my $help;
      eval "\$help = \$handler->help(\$mess);";
      return "Error calling help for handler $mess->{body}: $@" if $@;
      return $help;
    } else {
      return "I don't know anything about '$mess->{body}'.";
    }
  }
}

=item run

Runs the bot. POE core gets control at this point; you're unlikely to get it back.

=back

=cut

#########################################################
# the following routines are lifted from Bot::BasicBot: #
#########################################################
sub tick {
  my $self = shift;
  $self->dispatch('tick');
  return 5;
}

sub said {
  my $self = shift;
  my ($mess) = @_;
  my $response;
  my $who;
  
  for my $priority (0..3) {
    for ($self->handlers) {
      $who = $_;
      $response = eval { $self->handler($who)->said( $mess, $priority ) };
      warn $@ if $@;
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

sub reply {
  my ($self, $mess, @other) = @_;
  if ($mess->{reply_hook}) {
    return $mess->{reply_hook}->($mess, @other);
  } else {
    return $self->SUPER::reply($mess, @other);
  }
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

=head1 BUGS

During the C<make>, C<make test>, C<make install> process, POE will moan about
its kernel not being run. This is a C<Bot::BasicBot problem>, apparently.
Reloading a module causes warnings as the old module gets its namespace stomped.
Not a lot you can do about that. All modules must be in Bot::Pluggable::Module::
namespace. Well, that's not really a bug.                                                                                       

=head1 REQUIREMENTS

Bot::BasicBot::Pluggable is based on POE, and really needs the latest version.
Because POE is like that sometimes. You also need L<POE::Component::IRC>.
Oh, and L<Bot::BasicBot>. Some of the modules will need more modules, e.g.
Google.pm needs L<Net::Google>. See the module docs for more details.

=head1 AUTHOR

Tom Insam <tom@jerakeen.org>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 CREDITS

Bot::BasicBot was written initially by Mark Fowler, and worked on heavily by
Simon Kent, who was kind enough to apply some patches I needed for Pluggable.
Eventually. Oh, yeah, and I stole huge chunks of docs from the Bot::BasicBot
source too. I spent a lot of time in the mozbot code, and that has influenced
my ideas for Pluggable. Mostly to get round its awfulness.

Various people helped with modules. Convert was almost ported from the
infobot code by blech. But not quite. Thanks for trying... blech has also put
a lot of effort into the chump.cgi & chump.tem files in the examples/ folder,
including some /inspired/ calendar evilness.

And thanks to the rest of #2lmc who were my unwilling guinea pigs during
development. And who kept suggesting totally stupid ideas for modules that I
then felt compelled to go implement. Shout.pm owes its existence to #2lmc.

=head1 SEE ALSO

POE

L<POE::Component::IRC>

L<Bot::BasicBot>

Infobot: http://www.infobot.org/

Mozbot: http://www.mozilla.org/projects/mozbot/

=cut

1; # sigh.

