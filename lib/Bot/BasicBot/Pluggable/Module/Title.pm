package Bot::BasicBot::Pluggable::Module::Title;
use Bot::BasicBot::Pluggable::Module::Base;
use base qw(Bot::BasicBot::Pluggable::Module::Base);

=head1 NAME

Bot::BasicBot::Pluggable::Module::Title

=head1 SYNOPSIS

Speak the title of urls mentioned in channel

=head1 IRC USAGE

None. If the module is loaded, the bot will speak the titles of all web pages mentioned.

=cut

use URI::Title qw(title);

sub help {
    return "will speak the title of any wab page mentioned in channel";
}

sub said {
    my ($self, $mess, $pri) = @_;

    return unless ($pri == 0); # respond to everything mentioned.
    return unless ($mess->{channel} eq '#2lmc');
    return unless ($mess->{body} =~ m!(http://[^\|\s\]]+)!i);

    my $title = title($1) or return; # "Can't get $url";
    $self->reply($mess, "[ $title ]");

    return 0;
}

1;

