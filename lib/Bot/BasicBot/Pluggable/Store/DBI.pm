=head1 NAME

Bot::BasicBot::Pluggable::Store::DBI - A database B::B::P store

=head1 SYNOPSIS

  my $store = Bot::BasicBot::Pluggable::Store::DBI->new(
    dsn => "dbi:mysql:bot",
    user => "user",
    password => "password",
    table => "brane",
  );
  
  $store->set( "namespace", "key" => "value" );
  
=head1 DESCRIPTION

This is a L<Bot::BasicBot::Pluggable::Store> that uses a database to store
the values set by modules. Complex values are stored using Storable.

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
  my $user = $self->{user};
  my $password = $self->{password};
  $self->{dbh} ||= DBI->connect($dsn, $user, $password);
}

sub create_table {
  my $self = shift;
  my $table = $self->{table} or die "Need DB table";
  $self->dbh->do("CREATE TABLE $table (
    id INT PRIMARY KEY,
    namespace TEXT,
    store_key TEXT,
    store_value LONGBLOB
  )");
  return unless $self->{create_index};
  eval {
      $self->dbh->do("CREATE INDEX lookup ON $table ( namespace(10), store_key(10) )");
  };
  
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
      "INSERT INTO $table (id, store_value, namespace, store_key) VALUES (?, ?, ?, ?)"
    );
    $sth->execute($self->new_id($table), $value, $namespace, $key);
    $sth->finish;
  }
  return $self;
}

sub new_id {
  my $self = shift;
  my $table = shift;
  my $sth = $self->dbh->prepare_cached("SELECT MAX(id) FROM $table");
  $sth->execute();
  my $id = $sth->fetchrow_arrayref->[0] || "0";
  $sth->finish();
  return $id + 1;
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
  return undef unless $row and @$row;
  return eval { thaw($row->[0]) } || $row->[0];
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

sub namespaces {
  my ($self) = @_;
  my $table = $self->{table} or die "Need DB table";
  my $sth = $self->dbh->prepare_cached(
    "SELECT DISTINCT namespace FROM $table"
  );
  $sth->execute();
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
