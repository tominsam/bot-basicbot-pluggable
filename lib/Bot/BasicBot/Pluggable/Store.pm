=head1 NAME

Bot::BasicBot::Pluggable::Store

=head1 DESCRIPTION

Base class for the back-end pluggable store

=head1 SYNOPSIS

  my $store = Bot::BasicBot::Pluggable::Store->new( option => "Value" );

  my $name = $store->name;

  my $namespace = "MyModule";

  for ( $store->keys($namespace) ) {
    my $value = $store->get($namespace, $_);
    $store->set( $namespace, $_ => "$value and your momma" );
  }

'real' store classes should subclass this and provide some persistent
way of storing things.

=head1 METHODS

=over 4

=cut

package Bot::BasicBot::Pluggable::Store;
use warnings;
use strict;
use Carp qw( croak );
use Data::Dumper;

use base qw( );

sub new {
  my $class = shift;
  my $self = bless { @_ }, $class;
  $self->init();
  $self->load();
  return $self;
}

# subclass this for your store setup
sub init { }

# subclass this to load your data (assuming you want to at startup)
sub load { }

=head2 keys( namespace )

returns a list of all store keys

=cut

sub keys {
  my ($self, $namespace) = @_;
  return keys %{ $self->{store}{$namespace} || {} };
}

=head2 get( namespace, var )

returns the stored value of the key 'var'.

=cut

sub get {
  my ($self, $namespace, $key) = @_;
  return $self->{store}{$namespace}{$key};
}

=head2 set( namespace, key => val )

sets stored value for 'key' to 'val'. returns the store object.

=cut

sub set {
  my ($self, $namespace, $key, $value) = @_;
  $self->{store}{$namespace}{$key} = $value;
  return $self;
}

=head2 unset( namespace, key )

removes the key 'key' from the store. Returns the store object.

=cut

sub unset {
  my ($self, $namespace, $key) = @_;
  delete $self->{store}{$namespace}{$key};
  return $self;
}

1;

=back

=head1 SEE ALSO

Bot::BasicBot::Pluggable

Bot::BasicBot::Pluggable::Module

=head1 AUTHOR

Tom

=cut
