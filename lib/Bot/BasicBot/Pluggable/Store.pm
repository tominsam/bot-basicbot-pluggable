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
  $self->save($namespace);
  return $self;
}

=head2 unset( namespace, key )

removes the key 'key' from the store. Returns the store object.

=cut

sub unset {
  my ($self, $namespace, $key) = @_;
  delete $self->{store}{$namespace}{$key};
  $self->save($namespace);
  return $self;
}

=head2 namespaces()

returns a list of all namespaces in the store.

=cut

sub namespaces {
  my $self = shift;
  return CORE::keys(%{$self->{store}});
}

=head2 load()

=cut

sub load {}

=head2 save()

=cut

sub save {}

=head2 dump()

Dumps the complete store to a huge scalar. This is mostly so you can
convert from one store to another easily. Ie:

  my $from = Bot::BasicBot::Pluggable::Store::Storable->new();
  my $to   = Bot::BasicBot::Pluggable::Store::DBI->new( ... );
  $to->restore( $from->dump );

=cut

# dump is written generally, so that you don't have to re-implement it
# in subclasses. I hope. This does make it a leeetle inefficient, of 
# course.
use Storable;

sub dump {
  my $self = shift;
  my $data = {};
  for my $n ($self->namespaces) {
    warn "dumping namespace '$n'\n";
    for my $k ($self->keys($n)) {
      $data->{$n}{$k} = $self->get($n, $k);
    }
  }
  return Storable::nfreeze($data);
}

=head2 restore( data )

restores the store from a L<dump()>.

=cut

sub restore {
  my ($self, $dump) = @_;
  my $data = Storable::thaw($dump);
  for my $n (CORE::keys(%$data)) {
    warn "restoring namespace '$n'\n";
    for my $k (CORE::keys(%{ $data->{$n} })) {
      $self->set($n, $k, $data->{$n}{$k});
    }
  }
  warn "Complete\n";
}

1;

=back

=head1 SEE ALSO

Bot::BasicBot::Pluggable

Bot::BasicBot::Pluggable::Module

=head1 AUTHOR

Tom

=cut
