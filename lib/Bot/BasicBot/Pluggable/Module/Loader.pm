package Bot::BasicBot::Pluggable::Module::Loader;
use Bot::BasicBot::Pluggable::Module::Base;
use base qw(Bot::BasicBot::Pluggable::Module::Base);

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

sub save {
    my ($self) = @_;
    my $filename = "loader.settings";
    unless (open SAVE, ">$filename") {
        warn "Can't open settings file to save: $!\n";
        return;
    }
    for ($self->{Bot}->handlers) {
      print SAVE ( $self->{modules}{lc($_)} || $_ ) . "\n";
    }
    close SAVE;

}
    
sub load {
    my ($self) = @_;
    my $filename = "loader.settings";
    unless (open(LOAD, "<$filename")) {
        warn "Can't open settings file: $!\n";
        return;
    }
    my $reply = "";
    while (my $mod = <LOAD>) {
        chomp($mod);
        next unless ($mod);
        next if $mod =~ /^\s*$/;
        next if (lc($mod) eq "loader");
        my $status = ($self->{Bot}->load($mod)) ? "OK" : "NOT OK";
        $reply .= "Loading $mod: $status  ";
        print STDERR "Loading $mod: $status\n";
        $self->{modules}{lc($mod)} = $mod;
    }
    close LOAD;
    return $reply;
    
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
        return "Modules: ".join(", ", $self->{Bot}->handlers);
    }
    no warnings 'redefine';
    eval '
        if ($command eq "!load") {
             $self->{modules}{lc($param)} = $param;
             $self->{Bot}->load($param);
             die "success";
        } elsif ($command eq "!reload") {
             $self->{Bot}->reload($param);
             die "success";
        } elsif ($command eq "!unload") {
             $self->{Bot}->unload($param);
             die "success";
        }
    ';
    $self->save();
    return $@ if $@;
}

1;
