=head1 NAME

Bot::BasicBot::Pluggable::Store::Storable

=head1 DESCRIPTION

=head1 SYNOPSIS

=head1 METHODS

=over 4

=cut

package Bot::BasicBot::Pluggable::Store::Storable;
use warnings;
use strict;
use base qw( Bot::BasicBot::Pluggable::Store );

use Storable qw( nstore retrieve );

sub save {
  my $self = shift;
  my $namespace = shift;
  my @modules = $namespace ? ($namespace) : keys(%{ $self->{store} });

  for my $name ( @modules ) {
    my $filename = $name.".storable";
    #warn "Saving to $filename\n";
    nstore($self->{store}{$name}, $filename)
      or die "cannot save to $filename";
  }
  #warn "Done\n";
}

sub load {
  my $self = shift;
  for my $file (<*.storable>) {
    #warn "Loading storable file $file..\n";
    my ($name) = $file =~ /^(.*?)\.storable$/;
    $self->{store}{$name} = retrieve($file);
  }
  #warn "Done.\n";
}

1;

=back

=head1 SEE ALSO

=head1 AUTHOR

Tom

=cut
