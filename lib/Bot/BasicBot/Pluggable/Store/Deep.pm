package Bot::BasicBot::Pluggable::Store::Deep;

=head1 NAME

Bot::BasicBot::Pluggable::Store::Deep - use DBM::Deep to provide a storage backend

=head1 DESCRIPTION

This is a C<Bot::BasicBot::Pluggable::Store> that uses a C<DBM::Deep> to store
the values set by modules. 

=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>

=head1 COPYRIGHT

Copyright 2005, Simon Wistow

Distributed under the same terms as perl itself.

=cut

use warnings;
use strict;
use base qw( Bot::BasicBot::Pluggable::Store );

use DBM::Deep;

sub init {
	my $self = shift;
	delete $self->{type};
	$self->{_db} = DBM::Deep->new(%$self) || die "Couldn't connect to db - $self->{file}";
}

sub set {
	my ($self, $namespace, $key, $value) = @_;
	$self->{_db}->{$namespace}->{$key} = $value;
	return $self;
}

sub get {
  	my ($self, $namespace, $key) = @_;
	return $self->{_db}->{$namespace}->{$key};
}

sub unset {
	my ($self, $namespace, $key) = @_;
	delete $self->{_db}->{$namespace}->{$key};
}

sub keys {
	my ($self, $namespace) = @_;
	return keys %{ $self->{_db}->{$namespace}};
}

sub namespaces {
	my ($self) = @_;
	return CORE::keys %{ $self->{_db} };
}

1;

