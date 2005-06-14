=head1 NAME

Bot::BasicBot::Pluggable::Module::Title - speaks the title of URLs mentioned

=head1 IRC USAGE

None. If the module is loaded, the bot will speak the titles of all URLs mentioned.

=head1 REQUIREMENTS

L<URI::Title>

L<URI::Find::Simple>

=head1 AUTHOR

Tom Insam <tom@jerakeen.org>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

package Bot::BasicBot::Pluggable::Module::Title;
use base qw(Bot::BasicBot::Pluggable::Module);
use warnings;
use strict;

use Text::Unidecode;
use URI::Title qw(title);
use URI::Find::Simple qw(list_uris);

sub help {
    return "Speaks the title of URLs mentioned.";
}

sub admin {
    my ($self, $mess) = @_;

    my $reply = "";
    for (list_uris($mess->{body})) {
        my $title = title($_);
        $reply .= "[ ".unidecode($title)." ] " if $title;
    }

    return ($reply ne "") ? $reply : undef;
}

1;

