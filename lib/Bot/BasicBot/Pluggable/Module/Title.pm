package Bot::BasicBot::Pluggable::Module::Title;
use Bot::BasicBot::Pluggable::Module::Base;
use base qw(Bot::BasicBot::Pluggable::Module::Base);

=head1 NAME

Bot::BasicBot::Pluggable::Module::Title

=head1 SYNOPSIS

Speak the title of urls mentioned in channel

=head1 IRC USAGE

None. If the module is loaded, the bot will speak the titles of all web pages mentioned.

=head1 TODO

If you speak the URL of something big, the bot will download it all. It'll probably
then time out and drop off the server. Oops.

=cut

use LWP::Simple;

sub help {
    return "will speak the title of any wab page mentioned in channel";
}

sub said {
    my ($self, $mess, $pri) = @_;

    return unless ($pri == 0); # respond to everything mentioned.

    return unless ($mess->{body} =~ m!(http://\S+)!i);
    my $url = $1;

    my $data = get($url) or return; # "Can't get $url";

    my $title;
    my $match;

    if ($url =~ /theregister\.co\.uk/i) {
        $match = '<div class="storyhead">';
    } elsif ($url =~ /timesonline\.co\.uk/i) {
        $match = '<span class="headline">';
    } elsif ($url =~ /use\.perl\.org\/~([^\/]+).*journal\/\d/i) {
        $match = '<FONT FACE="geneva,verdana,sans-serif" SIZE="1"><B>';
        $title = "use.perl journal of $1 - ";
    } elsif ($url =~ /pants\.heddley\.com.*#(.*)$/i) {
        my $id = $1;
        $match = 'id="a'.$id.'"\/>[^<]*<a[^>]*>';
        $title = "pants daily chump - ";
    } elsif ($url =~ /paste\.husk\.org/i) {
        $match = 'Summary: ';
        $title = "paste - ";
        return if $mess->{who} eq 'pasty';
    } else {
        $match = '<title>';
    }

    $data =~ /$match([^<]+)/im or return; # "Can't find title";

    $title .= $1;
    $title =~ s/\s+$//;
    $title =~ s/^\s+//;
    $self->reply($mess, "[ $title ]");
    return 0;
}

1;

