=head1 NAME

Bot::BasicBot::Pluggable::Store::Deep - use DBM::Deep to provide a storage backend

=head1 SYNOPSIS

  my $store = Bot::BasicBot::Pluggable::Store::Deep->new(
    file => "filename"
  );

  $store->set( "namespace", "key", "value" );

=head1 DESCRIPTION

This is a C<Bot::BasicBot::Pluggable::Store> that uses C<DBM::Deep> to store
the values set by modules.

=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>

=head1 COPYRIGHT

Copyright 2005, Simon Wistow

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

package Bot::BasicBot::Pluggable::Store::Deep;
use warnings;
use strict;
use Carp qw( croak );
use DBM::Deep;

use base qw( Bot::BasicBot::Pluggable::Store );

sub init {
    my $self = shift;
    delete $self->{type};
    croak "You must pass a filename" unless defined $self->{file};
    $self->{_db} = DBM::Deep->new(%$self) || die "Couldn't connect to DB '$self->{file}'";
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
    my ($self, $namespace, %opts) = @_;
    # no idea why this works
    return CORE::keys %{$self->{_db}->{$namespace}} unless exists $opts{res} && @{$opts{res}};
    my $mod = $self->{_db}->{$namespace} || {} ;
    return $self->_keys_aux($mod, $namespace, %opts);
}

sub namespaces {
    my ($self) = @_;
    return CORE::keys %{ $self->{_db} };
}

1;

