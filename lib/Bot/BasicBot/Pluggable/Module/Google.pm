=head1 NAME

Bot::BasicBot::Pluggable::Module::Google - searches Google for terms and spellings

=head1 IRC USAGE

=over 4

=item google <terms>

Returns Google hits for the terms given.

=item spell <term>

Returns a Google spelling suggestion for the term given.

=back

=head1 VARS

To set module variables, use L<Bot::BasicBot::Pluggable::Module::Vars>.

=over 4

=item google_key

A valid Google API key is required for lookups.

=back

=head1 REQUIREMENTS

L<Net::Google>

L<http://www.google.com/apis/>

=head1 AUTHOR

Tom Insam E<lt>tom@jerakeen.orgE<gt>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut


package Bot::BasicBot::Pluggable::Module::Google;
use base qw(Bot::BasicBot::Pluggable::Module);
use warnings;
use strict;

use Net::Google;

sub init {
    my $self = shift;

    # default value for google_key, so it shows up in the list of vars.
    $self->set("user_google_key", "** SET ME FOR GOOGLE LOOKUPS **") unless $self->get("user_google_key");
}

sub help {
    return "Searches Google for terms and spellings. Usage: google <terms>, spell <words>.";
}

sub told {
    my ($self, $mess) = @_;
    my $body = $mess->{body};

    return unless $mess->{address};

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);

    if ($command eq "google") {
        return "No Google key has been set! Set it with '!set Google google_key <key>'." unless $self->get("user_google_key");

        my $google = Net::Google->new(key=>$self->get("user_google_key"));
        my $search = $google->search();
        $search->query(split(/\s+/, $param));
        $search->lr(qw(en fr));
        $search->ie("utf8");
        $search->oe("utf8");
        $search->starts_at(0);
        $search->max_results(3);

        my $res;
        $res .= $_->title.": ".$_->URL."\n" for @{$search->results()};
        $res =~ s/<[^>]+>//g;

        return "No results" unless $res;
        return "$res";

    } elsif ($command eq "spell") {
        return "No Google key has been set! Set it with '!set Google google_key <key>'." unless $self->get("user_google_key");

        my $google = Net::Google->new(key=>$self->get("user_google_key"));
        my $search = $google->search();

        my $res = $google->spelling(phrase=>$param)->suggest();
        return $res if $res;
        return "No clue";

    }
}

1;
