=head1 NAME

Bot::BasicBot::Pluggable::Module::Seen - track when and where people were seen

=head1 IRC USAGE

=over 4

=item seen <nick>

Find out when the last time a nick was seen and where.

=item hide

Hide yourself from the seen reporting.

=item unhide

Stops hiding yourself from the seen reporting.

=back

=head1 VARS

=over 4

=item allow_hiding

Defaults to 1; whether or not a nick can hide themselves from seen status.

=back

=head1 AUTHOR

Tom Insam <tom@jerakeen.org>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

package Bot::BasicBot::Pluggable::Module::Seen;
use base qw(Bot::BasicBot::Pluggable::Module);
use warnings;
use strict;

sub init {
    my $self = shift;
    $self->config({user_allow_hiding => 1});
}

sub help {
    return "Tracks when and where people were seen. Usage: seen <nick>, hide, unhide.";
}

sub seen {
    my ($self, $mess) = @_;
    my $what = 'saying "' . $mess->{body} . '"'; 
    $self->update_seen($mess->{who},$mess->{channel},$what);
    return;
}

sub chanpart {
    my ($self, $mess) = @_;
    my $what = 'leaving the channel';
    $self->update_seen($mess->{who},$mess->{channel},$what);
    return;
}

sub chanjoin {
    my ($self, $mess) = @_;
    my $what = 'joining the channel';
    $self->update_seen($mess->{who},$mess->{channel},$what);
    return;
}

sub update_seen {
    my ($self, $who,$channel,$what) = @_;
    my $nick = lc($who);
    $self->set( "seen_$nick" => {
        time    => time,
        channel => $channel,
        what    => $channel ne 'msg' ? $what : '<private message>',
    } );
}
	

sub told {
    my ($self, $mess) = @_;
    my $body = $mess->{body};
	return unless defined $body;

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);

    if ($command eq "seen" and $param =~ /^(.+?)\??$/) {
        my $who = lc($1);
        my $seen = $self->get("seen_$who");

        if (($self->get("user_allow_hiding") and $self->get("hide_$who")) or !$seen) {
            return "Sorry, I haven't seen $1.";
        }

        my $diff = time - $seen->{time};
        my $time_string = secs_to_string($diff);
        return "$1 was last seen in $seen->{channel} $time_string " . $seen->{what} . ".";

    } elsif ($command eq "hide" and $mess->{address}) {
        my $nick = lc($mess->{who});
        if (!$self->get("user_allow_hiding")) {
          return "Hiding has been disabled by the administrator.";
        }

        $self->set( "hide_$nick" => 1 );
        return "Ok, you're hiding from seen status.";

    } elsif ($command eq "unhide" and $mess->{address}) {
        my $nick = lc($mess->{who});
        $self->unset( "hide_$nick" );
        return "Ok, you're visible to seen status.";
    }
}

sub secs_to_string {
    my $secs = shift;

    # Hopefully never used. But if the seen time is in the future, catch it.
    my $weird = 0; if ($secs < 0) { $secs = -$secs; $weird = 1; }

    my $days  = int($secs / 86400); $secs = $secs % 86400;
    my $hours = int($secs / 3600);  $secs = $secs % 3600;
    my $mins  = int($secs / 60);    $secs = $secs % 60;

    my $string = "";
    $string   .= "$days days " if $days;
    $string   .= "$hours hours " if $hours;
    $string   .= "$mins mins " if ($mins and !$days);
    $string   .= "$secs seconds " if (!$days and !$hours);

    return $string. ($weird ? "in the FUTURE!!!" : "ago");
}

1;
