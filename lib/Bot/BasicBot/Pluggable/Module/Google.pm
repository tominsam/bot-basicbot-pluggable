package Bot::BasicBot::Pluggable::Module::Google;
use Bot::BasicBot::Pluggable::Module::Base;
use base qw(Bot::BasicBot::Pluggable::Module::Base);
our $VERSION = '0.05';

=head1 NAME

Bot::BasicBot::Pluggable::Module::Google

=head1 SYNOPSIS

Googles for things

=head1 IRC USAGE

Commands:

=over 4

=item google <terms>

Returns google hits for the terms given

=item spell <term>

Returns a google spelling suggestion for the wors given

=back

=head1 VARS

=over 4

=item google_key

The google API key to use for lookups. Must be set to use the module. The easiest
way to do this is to use the 'Vars' module and tell the bot

  '!set Google google_key <key>'

=back

=cut



use Net::Google;

sub init {
    my $self = shift;

    # default value for google_key is blank, so it shows up in the list of vars.
    $self->set("google_key", "") unless $self->get("google_key");
}

sub said {
    my ($self, $mess, $pri) = @_;
    my $body = $mess->{body};

    return unless ($pri == 2);

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);

    if ($command eq "google") {
        return "No google key set! Set it with '!set Google google_key <key>'." unless $self->get("google_key");

        print "Googling for $param\n";

        my $google = Net::Google->new(key=>$self->get("google_key"));
        my $search = $google->search();

        # Search interface
 
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
        return "No google key set! Set it with '!set Google google_key <key>'." unless $self->get("google_key");

        my $google = Net::Google->new(key=>$self->get("google_key"));
        my $search = $google->search();

        my $res = $google->spelling(phrase=>$param)->suggest();
        return $res if $res;
        return "No clue";

    }
}

sub help {
    return "Commands: 'google <terms>', or 'spell <words>'. The spelling module isn't very useful, though. Set a google_key with '!set Google google_key <key>' (after loading the Vars module)";
}

1;
