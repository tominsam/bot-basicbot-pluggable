package Bot::BasicBot::Pluggable::Module::Join;
use Bot::BasicBot::Pluggable::Module::Base;
use base qw(Bot::BasicBot::Pluggable::Module::Base);
our $VERSION = '0.05';

=head1 NAME

Bot::BasicBot::Pluggable::Module::Join

=head1 SYNOPSIS

Keeps track of what channels the bot wants to be in, will leave and join
channels on request. Load this module, and you can tell the bot 'join #channel',
'leave #channel', and it will remember it's state.

=head1 IRC USAGE

Commands:

=over 4

=item join <channel>

Joins a channel

=item part <channel>

Leaves a channel

=item channels

List the channels the bot is in

=back

=cut


sub connected {
    my ($self) = @_;
    print STDERR "Got connected() - joining channels\n";
    $self->load();

    for (keys(%{$self->{store}{channels}})) {
        print "Joining $_\n";
        $self->{Bot}->join($_);
    }
}

sub help {
    my ($self, $mess) = @_;
    return "Handles joining and leaving channels. usage: join <channel>, leave <channel>, channels. Requires direct addressing.";
}

sub said {
    my ($self, $mess, $pri) = @_;

    my $body = $mess->{body};

    return unless $mess->{address} and $pri == 2;

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);
    $command =~ s/\?$//;
    
    if ($command eq "join") {
        $self->{store}{channels}{lc($param)}++;
        $self->{Bot}->join($param);
        $self->save();
        return "Joining $param...";
    } elsif ($command eq "leave" or $command eq "part") {
        if ($self->{store}{channels}{lc($param)}) {
            delete $self->{store}{channels}{lc($param)};
            $self->{Bot}->part($param);
            $self->save();
            return "Leaving $param...";
        } else {
            return "I don't think I'm /in/ $param";
        } 
    } elsif ($command eq "channels") {
        return "I'm in ".join(", ", keys(%{$self->{store}{channels}}));
    }

    return undef;
}

1;
