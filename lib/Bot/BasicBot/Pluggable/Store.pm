=head1 NAME

Bot::BasicBot::Pluggable::Store - base class for the back-end pluggable store

=head1 SYNOPSIS

  my $store = Bot::BasicBot::Pluggable::Store->new( option => "value" );

  my $namespace = "MyModule";

  for ( $store->keys($namespace) ) {
    my $value = $store->get($namespace, $_);
    $store->set( $namespace, $_, "$value and your momma." );
  }

Store classes should subclass this and provide some persistent way of storing things.

=head1 METHODS

=over 4

=cut

package Bot::BasicBot::Pluggable::Store;
use warnings;
use strict;
use Carp qw( croak );
use Data::Dumper;
use Storable qw( nfreeze thaw );

use base qw( );

=item new()

Standard C<new> method, blesses a hash into the right class and puts any
key/value pairs passed to it into the blessed hash. Calls C<load()> to load any
internal variables, then C<init>, which you can also override in your module.

=cut

sub new {
  my $class = shift;
  my $self = bless { @_ }, $class;
  $self->init();
  $self->load();
  return $self;
}

=item init()

Called as part of new class construction, before C<load()>.

=cut

sub init { undef }

=item load()

Called as part of new class construction, after C<init()>.

=cut

sub load { undef }

=item save()

Subclass me. But, only if you want to. See ...Store::Storable.pm as an example.

=cut

sub save { }

=item keys($namespace,[$regex])

Returns a list of all store keys for the passed C<$namespace>.

If you pass C<$regex> then it will only pass the keys matching C<$regex>

=cut

sub keys {
  my ($self, $namespace, %opts) = @_;
  my $mod = $self->{store}{$namespace} || {};  
  return $self->_keys_aux($mod, $namespace, %opts);
}

sub count_keys {
  my ($self, $namespace, %opts) = @_;
  $opts{_count_only} = 1;
  $self->keys($namespace, %opts);
}

sub _keys_aux {
  my ($self, $mod, $namespace, %opts) = @_;

  my @res = (exists $opts{res}) ? @{$opts{res}} : ();

  return CORE::keys %$mod unless @res;

  my @return;
  my $count = 0;
  OUTER: while (my ($key) = each %$mod) {
        for my $re (@res) {
                # limit matches
                $re = "^".lc($namespace)."_.*${re}.*" if $re =~ m!^[^\^].*[^\$]$!;
                next OUTER unless $key =~ m!$re!
        }
        push @return, $key if (!$opts{_count_only});
        last if $opts{limit} &&  ++$count >= $opts{limit};

  }
  

  return ($opts{_count_only})? $count : @return;
}

=item get($namespace, $variable)

Returns the stored value of the C<$variable> from C<$namespace>.

=cut

sub get {
  my ($self, $namespace, $key) = @_;
  return $self->{store}{$namespace}{$key};
}

=item set($namespace, $variable, $value)

Sets stored value for C<$variable> to C<$value> in C<$namespace>. Returns store object.

=cut

sub set {
  my ($self, $namespace, $key, $value) = @_;
  $self->{store}{$namespace}{$key} = $value;
  $self->save($namespace);
  return $self;
}

=item unset($namespace, $variable)

Removes the C<$variable> from the store. Returns store object.

=cut

sub unset {
  my ($self, $namespace, $key) = @_;
  delete $self->{store}{$namespace}{$key};
  $self->save($namespace);
  return $self;
}

=item namespaces()

Returns a list of all namespaces in the store.

=cut

sub namespaces {
  my $self = shift;
  return CORE::keys(%{$self->{store}});
}

=item dump()

Dumps the complete store to a huge Storable scalar. This is mostly so
you can convert from one store to another easily, i.e.:

  my $from = Bot::BasicBot::Pluggable::Store::Storable->new();
  my $to   = Bot::BasicBot::Pluggable::Store::DBI->new( ... );
  $to->restore( $from->dump );

C<dump> is written generally so you don't have to re-implement it in subclasses.

=cut

sub dump {
  my $self = shift;
  my $data = {};
  for my $n ($self->namespaces) {
    warn "Dumping namespace '$n'.\n";
    for my $k ($self->keys($n)) {
      $data->{$n}{$k} = $self->get($n, $k);
    }
  }
  return nfreeze($data);
}

=item restore($data)

Restores the store from a L<dump()>.

=cut

sub restore {
  my ($self, $dump) = @_;
  my $data = thaw($dump);
  for my $n (CORE::keys(%$data)) {
    warn "Restoring namespace '$n'.\n";
    for my $k (CORE::keys(%{ $data->{$n} })) {
      $self->set($n, $k, $data->{$n}{$k});
    }
  }
  warn "Complete.\n";
}

1;

=back

=head1 AUTHOR

Tom Insam <tom@jerakeen.org>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

=head1 SEE ALSO

L<Bot::BasicBot::Pluggable>

L<Bot::BasicBot::Pluggable::Module>

=cut

1;
