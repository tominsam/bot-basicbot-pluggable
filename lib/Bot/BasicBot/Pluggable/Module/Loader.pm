=head1 NAME

Bot::BasicBot::Pluggable::Module::Loader

=head1 SYNOPSIS

Loads and unloads bot modules. Keeps track of loaded modules, and restores
them on bot startup. Load this module in the shell script that starts the bot,
and it should handle everything else for you.

=head1 IRC USAGE

Commands:

=over 4

=item !load <module>

Loads a module if possible, returns errors if any.

=item !unload <module>

Unloads a module

=item !reload <module>

Reloads a module

=item !list

Lists loaded modules

=back

=cut

package Bot::BasicBot::Pluggable::Module::Loader;
use warnings;
use strict;
use base qw(Bot::BasicBot::Pluggable::Module);

sub init {
    my $self = shift;
    warn "loader init\n";
    my @modules = $self->store_keys;
    for (@modules) {
      eval { $self->{Bot}->load($_) };
      warn "Error loading $_: $@" if $@;
    }
}


sub help {
    my ($self, $mess) = @_;
    return "Class loader and unloader for Bot::BasicBot::Pluggable. ".
        "usage: !load <module name>, !unload <modules name>, !reload <module name>";
}

sub said {
    my ($self, $mess, $pri) = @_;
    my $body = $mess->{body};

    return undef unless ($pri == 2);

    # we don't care about commands that don't start with '!'
    return undef unless $body =~ /^!/;

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);

    if ($command eq "!list") {
        return "Modules: ".join(", ", $self->store_keys);

    } elsif ($command eq "!load") {
        eval { $self->bot->load($param) } or return "Failed: $@";
        $self->set( $param => 1 );
        return "Success";

    } elsif ($command eq "!reload") {
        eval { $self->bot->reload($param) } or return "Failed: $@";
        return "Success";

    } elsif ($command eq "!unload") {
        eval { $self->bot->unload($param) } or return "Failed: $@";
        $self->unset( $param );
        return "Success";
    }

}

1;
