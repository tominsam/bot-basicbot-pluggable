package Bot::BasicBot::Pluggable::Module::Vars;
use Bot::BasicBot::Pluggable::Module::Base;
use base qw(Bot::BasicBot::Pluggable::Module::Base);
our $VERSION = '0.05';

=head1 NAME

Bot::BasicBot::Pluggable::Module::Vars

=head1 SYNOPSIS

Changes internal module variables. Bot modules have variables that they can
use to change their behaviour. This module, when loaded, gives people who
are logged in the ability to change these variables from the IRC interface.

=head1 IRC USAGE

Commands:

=over 4

=item !set <Module name> <variable name> <value>

Sets the variable in a given module. Module must be loaded.

=item !unset <module name> <variable name>

Unsets a variable.

=item !vars <module name>

Lists the variables in a module

=back

=cut

sub said {
    my($self, $mess, $pri) = @_;
    my $body = $mess->{body};
    
    return unless ($pri == 2); # most common
    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);

    if ($command eq "!set") {
        my ($mod, $var, $value) = split(/\s+/, $param, 3);
        return "Usage: !set <module> <var> <value>" unless $value;
        my $module = $self->{Bot}->module($mod);
        return "No such module" unless $module;
        $module->set($var, $value);
        return "Set.";
        
    } elsif ($command eq "!unset") {
        my ($mod, $var) = split(/\s+/, $param);
        return "Usage: !unset <module> <var>" unless $var;
        my $module = $self->{Bot}->module($mod);
        return "No such module" unless $module;
        $module->unset($var);
        return "Unset.";
        
    } elsif ($command eq "!vars") {
        my $module = $self->{Bot}->module($param);
        return "No such module" unless $module;
        return "$param has no vars" unless $module->{store}{vars};
        my %vars = %{$module->{store}{vars}};
        my $response = "Variables for $param: ";
        for (keys(%vars)) {
            $response .= "[ $_ = '$vars{$_}' ] ";
        }
        return $response;
    }

}

sub help {
    return "Usage: !set <module> <var> <value>, or !vars <module> to list vars for a module.";
}

1;
