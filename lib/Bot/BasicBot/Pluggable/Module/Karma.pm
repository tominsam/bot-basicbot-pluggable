=head1 NAME

Bot::BasicBot::Pluggable::Module::Karma - tracks karma for various concepts

=head1 IRC USAGE

=over 4

=item <thing>++ # <comment>

Increases the karma for <thing>.

=item <thing>-- # <comment>

Decreases the karma for <thing>.

=item karma <thing>

Replies with the karma rating for <thing>.

=item explain <thing>

Lists three each good and bad things said about <thing>:

  <user> explain Morbus
  <bot> positive: committing lots of bot documentation; fixing the
        fisher_yates; negative: filling the dev list. overall: 5

=back

=head1 METHODS

=over 4

=item get_karma($username)

Returns either a string representing the total number of karma points for
the passed C<$username> or the total number of karma points, an array of
good karma comments, and an array of bad comma comments. The number of 
good/bad comments returned can be configured with num_comments, below.

=item add_karma($object, $good, $reason, $who)

Adds or subtracts from the passed C<$object>'s karma. C<$good> is either 1 (to
add a karma point to the C<$object> or 0 (to subtract). C<$reason> is an 
optional string commenting on the reason for the change, and C<$who> is the
person modifying the karma of C<$object>. Nothing is returned.

=back

=head1 VARS

=over 4

=item ignore_selfkarma

Defaults to 1; determines whether to respect selfkarmaing or not.

=item num_comments

Defaults to 3; number of good and bad comments to display on explanations.

=item show_givers

Defaults to 1; whether to show who gave good or bad comments on explanations.

=back

=head1 AUTHOR

Tom Insam <tom@jerakeen.org>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

package Bot::BasicBot::Pluggable::Module::Karma;
use base qw(Bot::BasicBot::Pluggable::Module);
use warnings;
use strict;

sub init {
    my $self = shift;
    $self->set("user_ignore_selfkarma", 1) unless defined($self->get("user_ignore_selfkarma"));
    $self->set("user_num_comments", 3) unless defined($self->get("user_num_comments"));
    $self->set("user_show_givers", 1) unless defined($self->get("user_show_givers"));
}

sub help {
    return "Gives karma for or against a particular thing. Usage: <thing>++ # comment, <thing>-- # comment, karma <thing>, explain <thing>.";
}

sub seen {
    my ($self, $mess) = @_;
    my $body = $mess->{body};
	return 0 unless defined $body;
    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);

    if (($body =~ /(\w+)\+\+\s*#?\s*/) or ($body =~ /\(([\w\s]+)\)\+\+\s*#?\s*/)) {
        return if (($1 eq $mess->{who}) and $self->get("user_ignore_selfkarma"));
        return $self->add_karma($1, 1, $', $mess->{who});
    } elsif (($body =~ /(\w+)\-\-\s*#?\s*/) or ($body =~ /\(([\w\s]+)\)\-\-\s*#?\s*/)) {
        return if (($1 eq $mess->{who}) and $self->get("user_ignore_selfkarma"));
        return $self->add_karma($1, 0, $', $mess->{who});
    } elsif ($mess->{address} && ($body =~ /\+\+\s*#?\s*/)) {
        return $self->add_karma($mess->{address}, 1, $', $mess->{who});
    # our body check here is constrained to the beginning of the line with
    # an optional "-" of "--" because Bot::BasicBot sees "<botname>-" as being
    # an addressing mode (along with "," and ":"). so, "<botname>--" comes
    # through as "<botname>-" in {address} and "-" as the start of our body.
    # TODO: add some sort of $mess->{rawbody} to Bot::BasicBot.pm. /me grumbles.
    } elsif ($mess->{address} && ($body =~ /\-?\-\s*#?\s*/)) {
        return $self->add_karma($mess->{address}, 0, $', $mess->{who});
    }
}

sub told {
    my ($self, $mess) = @_;
    my $body = $mess->{body};

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);

    my $nick = $self->bot->nick;

    my $tmp = $command;
    $tmp =~ s!^$nick!!;
    if ($tmp eq '++') {
       return "Thanks!";
    } elsif ($tmp eq '--') {
       return "Pbbbbtt!";
    }
    

    if ($command eq "karma" and $param) {
        return "$param has karma of ".$self->get_karma($param).".";

    } elsif ($command eq "karma" and !$param) {
        return $mess->{who} ." has karma of ".$self->get_karma($mess->{who}).".";

    } elsif ($command eq "explain" and $param) {
        $param =~ s/^karma\s+//i;
        my ($karma, $good, $bad) = $self->get_karma($param);
        #$self->trim_list($good, $self->get("user_num_comments"));
        #$self->trim_list($bad, $self->get("user_num_comments"));
        my $reply  = "positive: ".scalar(@$good)."; ";
           $reply .= "negative: ".scalar(@$bad)."; ";
           $reply .= "overall: $karma.";

        return $reply;
    } 
}

sub get_karma {
    my ($self, $object) = @_;
    $object = lc($object);
    $object =~ s/-/ /g;

    my @changes = @{ $self->get("karma_$object") || [] };

    my (@good, @bad);
    my $karma = 0;

    for my $row (@changes) {
        my $who = $self->get("user_show_givers") ? " (".$row->{who}.")" : undef; 
        if ($row->{positive}) { $karma++; push(@good, $row->{reason}.$who) }
        else                  { $karma--; push(@bad, $row->{reason}.$who)  }
    }

    return wantarray() ? ($karma, \@good, \@bad) : $karma;
}

sub add_karma {
    my ($self, $object, $good, $reason, $who) = @_;
    $object = lc($object); $object =~ s/-/ /g;
    my $row = { reason=>$reason, who=>$who, timestamp=>time, positive=>$good };
    my @changes = @{ $self->get("karma_$object") || [] }; push @changes, $row;
    $self->set( "karma_$object" => \@changes );
    return 1;
}

sub trim_list {
    my ($self, $list, $count) = @_;
    fisher_yates_shuffle($list);
    if (scalar(@$list) > $count) {
        @$list = splice(@$list, 0, $count);
    }
}

sub fisher_yates_shuffle {
    my $array = shift;
    my $i = @$array;
    while ($i--) {
        my $j = int rand ($i+1);
        @$array[$i,$j] = @$array[$j,$i];
    }
}

1;
