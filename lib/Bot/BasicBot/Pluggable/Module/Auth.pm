=head1 NAME

Bot::BasicBot::Pluggable::Module::Auth

=head1 SYNOPSIS

Authentication for Bot::BasicBot::Pluggable modules

This module catches messages at priority '1' and stops anything starting
with '!' unless the user is authed, so most admin modules, eg Loader, can
merely sit at priority 2, and assume that the user is authed if the command
reaches them.

If you want to use modules that can change bot state, like Loader or Vars,
you almost certainly want this module.

=head1 IRC INTERFACE

Commands:

=over 4

=item !auth <username> <password>

Authenticate to the bot with a username and password. Logins timeout after
an hour, so you'll have to re-auth if you've been away.

=item !adduser <username> <password>

Adds a user with the given password

=item !password <oldpassword> <new password>

Change your current password (must be logged in)

=item !users

List all the users the bot knows about.

=item deluser <username>

Deletes a user. Don't delete yourself, that's probably not a good idea.

=back

The default user is 'admin', password 'julia'. Change this.


=head1 MODULE INTERFACE

The only useful command is 'authed':

  if ($bot->module("Auth")->authed("jerakeen")) {
  ..

returns 1 if the given nick is logged in, 0 otherwise.


=head1 BUGS

All users are admins. This is fine at the moment, as the only things that
need you to be logged in are admin functions.

Passwords are stored in plaintext, and are trivial to extract for any module
on the system. I don't consider this a bug, because I assume you trust the
modules you're loading.

If Auth is /not/ loaded, all users effectively have admin permissions.
This may not be a good idea, but is also not an Auth bug, it's an
architecture bug.

=cut

package Bot::BasicBot::Pluggable::Module::Auth;
use base qw(Bot::BasicBot::Pluggable::Module);
use warnings;
use strict;

sub init {
    my $self = shift;
    
    unless ( $self->get("password_admin") ) {
        $self->set("password_admin" => "julia"); # mmmm, defaults.
    }
}

sub help {
    my ($self, $bot, $mess) = @_;
    return "Authenticator for admin-level commands. usage: !auth <pass> to authenticate";
}

sub said {
    my ($self, $mess, $pri) = @_;
    my $body = $mess->{body};

    return unless ($pri == 1);
    return unless ($body and length($body) > 4);

    # we don't care about commands that don't start with '!'
    return 0 unless $body =~ /^!/;

    # system commands have to be directly addressed.
    return 1 unless $mess->{address};

    # ..and in privmsg
    return "Admin commands in privmsg only, please"
      unless !defined $mess->{channel} || $mess->{channel} eq 'msg';

    if ($body =~ /^!auth\s+(\w+)\s+(\w+)/) {
        my $user = $1;
        my $pass = $2;
        my $stored = $self->get("password_".$user);

        if ( $pass and $stored and $pass eq $stored ) {
            $self->{auth}{$mess->{who}}{time} = time();
            $self->{auth}{$mess->{who}}{username} = $user;
            if ($user eq "admin" and $pass eq "julia") {
                return "Authenticated. But change the password - you're using the default.";
            }
            return "Authenticated.";

        } else {
            delete $self->{auth}{$mess->{who}};
            return "Bad password";
        }

    } elsif ($body =~ /^!auth/) {
        return "Bad auth. usage: !auth <username> <password>\n";
        
    } elsif ($body =~ /^!adduser\s+(\w+)\s+(\w+)/) {
        my $user = $1;
        my $pass = $2;
        if ($self->authed($mess->{who})) {
            $self->set( "password_".$user, $pass );
            return "Added user $user";
        } else {
            return "You need to authenticate.";
        }

    } elsif ($body =~ /^!adduser/) {
        return "usage: adduser <username> <password>";

    } elsif ($body =~ /^!deluser\s+(\w+)/) {
        my $user = $1;
        if ($self->authed($mess->{who})) {
            $self->unset( "password_".$user );
            return "Deleted user $user";
        } else {
            return "You need to authenticate.";
        }

    } elsif ($body =~ /^!deluser/) {
        return "usage: deluser <username>";

    } elsif ($body =~ /^!passw?o?r?d?\s+(\w+)\s+(\w+)/) {
        my $old_pass = $1;
        my $pass = $2;
        if ($self->authed($mess->{who})) {
            my $username = $self->{auth}{$mess->{who}}{username};
            if ( $old_pass eq $self->get("password_$username") ) {
                $self->set("password_$username", $pass);
                return "Changed password to $pass";
            } else {
                return "wrong password";
            }

        } else {
            return "You need to authenticate.";
        }
    } elsif ($body =~ /^!passw?o?r?d?/) {
        return "usage: !passwd <old password> <newpassword>";

    } elsif ($body =~ /^!users/) {
        return "Users: ".join(", ", map { s/^password_// ? $_ : () } $self->store_keys);

    } else {

        if ($self->authed($mess->{who})) {
            return undef;
        } else {
            return "You need to authenticate.";
        }
    }
    return "Bad fallthrough.";
}

sub authed {
    my ($self, $username) = @_;

    return 1 if ($self->{auth}{$username}{time}
             and $self->{auth}{$username}{time} + 7200 > time());

    return 0;
    
}

1;
