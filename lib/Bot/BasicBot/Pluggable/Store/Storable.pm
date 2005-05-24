=head1 NAME

Bot::BasicBot::Pluggable::Store::Storable - use Storable to provide a storage backend

=head1 SYNOPSIS

  my $store = Bot::BasicBot::Pluggable::Store::Storable->new(
    file => "filename"
  );

  $store->set( "namespace", "key", "value" );
  
=head1 DESCRIPTION

This is a L<Bot::BasicBot::Pluggable::Store> that uses Storable to store
the values set by modules.

=head1 AUTHOR

Tom Insam <tom@jerakeen.org>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

package Bot::BasicBot::Pluggable::Store::Storable;
use warnings;
use strict;
use Storable qw( nstore retrieve );

use base qw( Bot::BasicBot::Pluggable::Store );

sub save {
  my $self = shift;
  my $namespace = shift;
  my @modules = $namespace ? ($namespace) : keys(%{ $self->{store} });

  for my $name ( @modules ) {
    my $filename = $name.".storable";
    nstore($self->{store}{$name}, $filename)
      or die "Cannot save to $filename";
  }
}

sub load {
  my $self = shift;
  for my $file (<*.storable>) {
    my ($name) = $file =~ /^(.*?)\.storable$/;
    $self->{store}{$name} = retrieve($file);
  }
}

1;
