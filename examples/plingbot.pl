#!/usr/bin/perl -w
use strict;
use warnings;

package PlingBot;
use base qw(Bot::BasicBot);

sub said {
  my $self = shift;
  my $mess = shift;

  return unless ($mess->{body} =~ /\!{2,}/);

  $self->say( body => "Oi! No shouting!", channel => $mess->{channel} );
  return;
}

package main;


PlingBot->new(
  channels => ['#jerakeen'],
  nick => 'plingbot',
  server => 'london.irc.perl.org',
)->run();

