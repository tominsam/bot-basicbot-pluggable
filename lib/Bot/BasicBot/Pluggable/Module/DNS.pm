package Bot::BasicBot::Pluggable::Module::DNS;
use base qw(Bot::BasicBot::Pluggable::Module);

=head1 NAME

Bot::BasicBot::Pluggable::Module::DNS

=head1 SYNOPSIS

Does DNS lookups for hosts.

=head1 IRC USAGE

Commands:

=over 4

=item nslookup <name>

returns the IP address of the named host

=item dns <ip address>

reuturns the name of the host with that IP

=back

=head1 TODO

=cut


use Socket;

sub said {
    my ($self, $mess, $pri) = @_;
    my $body = $mess->{body};

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);

    return unless ($pri == 2);

    if ($command eq "nslookup") {
        my @addr = gethostbyname($param);
        my $straddr = inet_ntoa($addr[4]);
        return "$param is $straddr";
    } elsif ($command eq "dns") {
        my $addr = inet_aton($param);
        my @addr = gethostbyaddr($addr, AF_INET);
        return "$param is $addr[0]";
    }
}

sub help {
    return "Does DNS lookups. Commands: 'nslookup <name>' for the IP, 'dns <ip>' for a name,";
}


1;
