package Bot::BasicBot::Pluggable;

use strict;
use warnings;
no warnings 'redefine';

use POE;
use Bot::BasicBot;
use Carp qw(croak);

our @ISA = qw(Bot::BasicBot);

our $VERSION = '0.2';

=head1 NAME

Bot::BasicBot::Pluggable - extension to the simple irc bot base class
allowing for pluggable modules

=head1 SYNOPSIS

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

  # Load some useful modules
  my $infobot_module = $bot->load("Infobot");
  my $google_module = $bot->load("Google");
  my $seen_module = $bot->load("Seen");

  # Set the google key (see http://www.google.com/apis/)
  $google_module->set("google_key", "some google key");
  
  $bot->run();


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

=head2 Main Methods

=over 4

=item new

Create a new Bot. Identical to the new method in Bot::BasicBot.

=item load($module)

Load a module for the bot by name, from, by preference './Modules/$module.pm',
but will fall back to Bot::BasicBot::Pluggable::Module::$module if this
isn't available.

=cut

sub load {
    my $self = shift;
    my $module = shift;
    
    croak "Already have a handler with that name" if $self->handler($module);

    # This is possible a leeeetle bit evil.
    my $file = "Bot/BasicBot/Pluggable/Module/$module.pm";
    eval "
        delete \$INC{\$file};
        require \$file;
    ";
    # Ok, it's very evil. Don't bother me, I'm working.

    croak "Can't eval module: $@" if $@;

    my $m;
    eval "\$m = Bot::BasicBot::Pluggable::Module::$module->new(Name=>\$module, Bot=>\$self, Param=>\\\@_);";
    
    croak "Can't call $module->new(): $@" if $@;

    croak "->new didn't return an object" unless $m;

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

    print STDERR "Reloading module $module\n";

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

    print STDERR "Unloading module $module\n";

    return "Need name" unless $module;
    return "Not loaded" unless $self->handler($module);

    $self->remove_handler($module);
    return "Removed";
}

=item reply($mess, $body)

Reply to a Bot::BasicBot message $mess. Will reply to an incoming message
with the text '$body', in a privmsg if $mess was a privmsg, in channel if
not, and prefixes if $mess was prefixed. Mostly a shortcut method.

=cut

sub reply {
    my $self = shift;
    my ($mess, $body) = @_;
    my %hash = %$mess;
    $hash{body} = $body;
    return $self->say(%hash);
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

returns a list of loaded moudues, as an array or an arrayref depending on
what context it's called in.

=cut

sub modules {
    my $self = shift;
    return $self->handlers(@_);
}


sub handler {
    my ($self, $name) = @_;
    return $self->{handlers}{$name};
}

sub handlers {
    my $self = shift;
    my @keys = keys(%{$self->{handlers}});
    return @keys if wantarray;
    return \@keys;
}

sub add_handler {
    my ($self, $handler, $name) = @_;
    croak "Need a name for adding a handler" unless $name;
    croak "Can't load a handler with a duplicate name $name" if $self->{handlers}{$name};
    $self->{handlers}{$name} = $handler;    
}

sub remove_handler {
    my ($self, $name) = @_;
    croak "Need a name for removing a handler" unless $name;
    croak "Hander $name not defined" unless $self->{handlers}{$name};
    delete $self->{handlers}{$name};
    return "Done.";
}

####################################################
# ..from Bot::BasicBot:

sub dispatch {
    my $self = shift;
    my $method = shiftl;

    for my $who ($self->handlers) {
        next unless $self->handler($who)->can($method);
        eval "\$self->handler(\$who)->$method(\@_);";
        print STDERR $@ if $@;
    }
    return undef;
}

sub tick {
    shift->dispatch("tick");
}

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
                my $shorter;
                while ($response) {
                    $shorter .= substr($response, 0, 300, "");
                }
                $self->reply($mess, $_) for split(/\n/, $shorter);
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
    print STDERR "Bot::BasicBot::connected()\n";
    shift->dispatch('connected');
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

The chump example code in examples/ is EVIL. Very. I'll tidy it, muttley has
promised me a Text::Chump or something soon. It's there more as a
placeholder for something /good/, really.

More other things than I can shake a stick at.

=head1 SEE ALSO

POE

POE::Component::IRC

Bot::BasicBot

Possibly Infobot, at http://www.infobot.org, and Mozbot, somewhere in mozilla.org.

=cut

1; # sigh.

