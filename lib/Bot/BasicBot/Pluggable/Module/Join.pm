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

package Bot::BasicBot::Pluggable::Module::Join;
use warnings;
use strict;

use Bot::BasicBot::Pluggable::Module;
use base qw(Bot::BasicBot::Pluggable::Module);

sub connected {
    my $self = shift;

    my @channels = split(/\s+/, $self->get("channels") || "");
    for (@channels) {
        print "Joining $_\n";
        $self->{Bot}->join($_);
    }
}

sub help {
    my ($self, $mess) = @_;
    return "Handles joining and leaving channels. ".
    "usage: join <channel>, leave <channel>, channels. ".
    "Requires direct addressing.";
}

sub said {
    my ($self, $mess, $pri) = @_;

    my $body = $mess->{body};

    return unless $mess->{address} and $pri == 2;

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);
    $command =~ s/\?$//;

    if ($command eq "join") {
        $self->add_channel($param);
        return "Ok.";

    } elsif ($command eq "leave" or $command eq "part") {
        $self->remove_channel($param || $mess->{channel} );
        return "Ok.";

    } elsif ($command eq "channels") {
        return "I'm in ".$self->get("channels");
    }

    return undef;
}

sub add_channel {
    my ($self, $channel) = @_;
    my %channels = map { $_ => 1 } split(/\s+/, $self->get("channels"));
    $channels{$channel} = 1;
    $self->set( channels => join(" ", keys %channels) );
    $self->bot->join($channel);
}

sub remove_channel {
    my ($self, $channel) = @_;
    my %channels = map { $_ => 1 } split(/\s+/, $self->get("channels"));
    delete $channels{$channel};
    $self->set( channels => join(" ", keys %channels) );
    $self->bot->part($channel);
}

1;
