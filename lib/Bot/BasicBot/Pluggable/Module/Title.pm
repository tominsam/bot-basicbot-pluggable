package Bot::BasicBot::Pluggable::Module::Title;
use Bot::BasicBot::Pluggable::Module::Base;
use base qw(Bot::BasicBot::Pluggable::Module::Base);

use LWP::Simple;

our $VERSION = '0.3';

sub said {
    my ($self, $mess, $pri) = @_;

    return unless ($pri == 3);
    return unless ($mess->{channel} eq "#2lmc" or $mess->{address});

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
    return "[ $title ]";
}

1;

