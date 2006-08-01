=head1 NAME

Bot::BasicBot::Pluggable::Module::Join - join and leave channels; remembers state

=head1 IRC USAGE

=over 4

=item join <channel>

=item part <channel>

=item channels

List the channels the bot is in.

=back

=head1 METHODS

=over 4

=item add_channel($channel)

=item remove_channel($channel)

=back

=head1 AUTHOR

Tom Insam <tom@jerakeen.org>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

package Bot::BasicBot::Pluggable::Module::Join;
use base qw(Bot::BasicBot::Pluggable::Module);
use warnings;
use strict;

sub connected {
    my $self = shift;

    my @channels = split(/\s+/, $self->get("channels") || "");
    for (@channels) {
        print "Joining $_.\n";
        $self->{Bot}->join($_);
    }
}

sub help {
    return "Join and leave channels. Usage: join <channel>, leave <channel>, channels. Requires direct addressing.";
}

sub told {
    my ($self, $mess) = @_;
    my $body = $mess->{body};
	return unless defined $body;
    return unless $mess->{address};

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);

    if ($command eq "join") {
        $self->add_channel($param);
        return "Ok.";

    } elsif ($command eq "leave" or $command eq "part") {
        $self->remove_channel($param || $mess->{channel});
        return "Ok.";

    } elsif ($command eq "channels") {
        return "I'm in ".$self->get("channels").".";
    }
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
