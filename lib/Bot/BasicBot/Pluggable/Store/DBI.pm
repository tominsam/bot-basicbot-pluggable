=head1 NAME

Bot::BasicBot::Pluggable::Store::DBI

=head1 DESCRIPTION

=head1 SYNOPSIS

=head1 METHODS

=over 4

=cut

package Bot::BasicBot::Pluggable::Store::DBI;
use warnings;
use strict;
use Carp qw( croak );
use Data::Dumper;
use Storable qw( nfreeze thaw );
use DBI;

use base qw( Bot::BasicBot::Pluggable::Store );

sub init {
  my $self = shift;
  $self->create_table;
}

sub dbh {
  my $self = shift;
  my $dsn = $self->{dsn} or die "I need a DSN";
  my $user = $self->{user} or die "I need a user";
  my $password = $self->{password};
  $self->{dbh} ||= DBI->connect($dsn, $user, $password);
}

sub create_table {
  my $self = shift;
  my $table = $self->{table} or die "Need DB table";
  $self->dbh->do("CREATE TABLE $table (
    id INT PRIMARY KEY AUTO_INCREMENT,
    namespace TEXT,
    store_key TEXT,
    store_value LONGBLOB
  )");
  $self->dbh->do("CREATE INDEX lookup ON $table ( namespace(10), store_key(10) )");

}

sub set {
  my ($self, $namespace, $key, $value) = @_;
  my $table = $self->{table} or die "Need DB table";
  $value = nfreeze($value) if ref($value);
  my $sql;
  if (defined($self->get($namespace, $key))) {
    my $sth = $self->dbh->prepare_cached(
      "UPDATE $table SET store_value=? WHERE namespace=? AND store_key=?"
    );
    $sth->execute($value, $namespace, $key);
    $sth->finish;
  } else {
    my $sth = $self->dbh->prepare_cached(
      "INSERT INTO $table (store_value, namespace, store_key) VALUES (?, ?, ?)"
    );
    $sth->execute($value, $namespace, $key);
    $sth->finish;
  }
  return $self;
}

sub get {
  my ($self, $namespace, $key) = @_;
  my $table = $self->{table} or die "Need DB table";
  my $sth = $self->dbh->prepare_cached(
    "SELECT store_value FROM $table WHERE namespace=? and store_key=?"
  );
  $sth->execute($namespace, $key);
  my $row = $sth->fetchrow_arrayref;
  $sth->finish;
  return undef unless my $value = $row->[0];
  return eval { thaw($value) } || $value;
}

sub unset {
  my ($self, $namespace, $key) = @_;
  my $table = $self->{table} or die "Need DB table";
  my $sth = $self->dbh->prepare_cached(
    "DELETE FROM $table WHERE namespace=? and store_key=?"
  );
  $sth->execute($namespace, $key);
  $sth->finish;
}

sub keys {
  my ($self, $namespace) = @_;
  my $table = $self->{table} or die "Need DB table";
  my $sth = $self->dbh->prepare_cached(
    "SELECT store_key FROM $table WHERE namespace=?"
  );
  $sth->execute($namespace);
  my @keys = map { $_->[0] } @{ $sth->fetchall_arrayref };
  $sth->finish;
  return @keys;
}

1;

=back

=head1 SEE ALSO

=head1 AUTHOR

Tom

=cut
