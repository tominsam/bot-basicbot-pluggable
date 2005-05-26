=head1 NAME

Bot::BasicBot::Pluggable::Module::Infobot - infobot clone redone in B::B::P.

=head1 SYNOPSIS

Does infobot things - basically remembers and returns factoids. Will ask
another infobot about factoids that it doesn't know about, if you want. Due
to persistent heckling from the peanut gallery, does things pretty much
exactly like the classic infobot, even when they're not necessarily that
useful (for example, saying "Okay." rather than "OK, water is wet."). Further
infobot backwards compatibility is available through additional packages
such as L<Bot::BasicBot::Pluggable::Module::Foldoc>.

=head1 IRC USAGE

The following examples assume you're running Infobot with its defaults settings,
which require the bot to be addressed before learning factoids or answering
queries. Modify these settings with the Vars below.

  <user> bot: water is wet.
   <bot> user: okay.
  <user> bot: water?
   <bot> user: water is wet.
  <user> bot: water is also blue.
   <bot> user: okay.
  <user> bot: water?
   <bot> user: water is wet or blue.
  <user> bot: no, water is translucent.
   <bot> user: okay.
  <user> bot: water?
   <bot> user: water is translucent.
  <user> bot: forget water.
   <bot> user: I forgot about water.
  <user> bot: water?
   <bot> user: No clue. Sorry.

A fact that begins with "<reply>" will have the "<noun> is" stripped:

  <user> bot: what happen is <reply>somebody set us up the bomb.
   <bot> user: okay.
  <user> bot: what happen?
   <bot> user: somebody set us up the bomb.

A fact that begins "<action>" will be emoted as a response:

  <user> bot: be funny is <action>dances silly.
   <bot> user: okay.
  <user> bot: be funny?
    * bot dances silly.

Pipes ("|") indicate different possible answers, picked at random:

  <user> bot: dice is one|two|three|four|five|six
   <bot> user: okay.
  <user> bot: dice?
   <bot> user: two.
  <user> bot: dice?
   <bot> user: four.
  
You can also use RSS feeds as a response:

  <user> bot: jerakeen.org is <rss="http://jerakeen.org/rss">.
   <bot> user: okay.
  <user> bot: jerakeen.org?
   <bot> user: jerakeen.org is <item>; <item>; etc...

You can also ask the bot to learn a factoid from another bot, as follows:

  <user> bot: ask bot2 about fact.
   <bot> user: asking bot2 about fact...
  <user> bot: fact?
   <bot> user: fact is very boring.

=head1 VARS

=over 4

=item passive_answer

Defaults to 0; when enabled, the bot will answer factoids without being addressed.

=item passive_learn

Defaults to 0; when enabled, the bot will learn factoids without being addressed.

=item stopwords

A comma or space separated list of words the bot should not learn or answer for.
This prevents such insanity as the learning of "where is the store?" and "how
is your mother?" The default list of stopwords is: "here how it something
that that this what when where which which who why".

=back

=head1 BUGS

If we request an RSS feed that takes a long time, we'll timeout and drop off.

"is also" doesn't work on <reply>s (ie. "<bot> cheetahs! or <reply>monkies.")

"is also" doesn't work on <action>s (same as the previous bug, hobo.)

The pipe syntax for random replies doesn't actually work. At all. Um.

"no, <bot>, <fact> is <response>" should be possible, but isn't.

If bot is in passive_learn, it'll complain about resetting facts.

There needs to be a settable limit on how many RSS items to return.

There needs to be a settable list of "No clue. Sorry" responses.

"<bot>?" fails, due to removal of <bot> name from $mess->body.

"ask" syntax doesn't work in a private message.

"water." and "water" are entirely different factoids.

The tab stops are set to 2, not 4. OHMYGOD.

=head1 REQUIREMENTS

URI

L<LWP::Simple>

L<XML::Feed>

=head1 AUTHOR

Tom Insam <tom@jerakeen.org>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

package Bot::BasicBot::Pluggable::Module::Infobot;
use base qw(Bot::BasicBot::Pluggable::Module);
use warnings;
use strict;

use LWP::Simple ();
use XML::Feed;
use URI;

sub init {
    my $self = shift;
    $self->set("user_passive_answer", 0) unless defined($self->get("user_passive_answer"));
    $self->set("user_passive_learn", 0) unless defined($self->get("user_passive_learn"));
    $self->set("user_stopwords", "here how it something that that this what when where which which who why") unless defined($self->get("user_stopwords"));
    $self->set("db_version" => "1") unless $self->get("db_version");

    # record what we've asked other bots.
    $self->{remote_infobot} = {};
}

sub help {
    return "An infobot. See http://search.cpan.org/perldoc?Bot::BasicBot::Pluggable::Module::Infobot.";
}

sub told {
  my ($self, $mess) = @_;
  my $body = $mess->{body};

  # looks like an infobot reply
  if ($body =~ s/^:INFOBOT:REPLY (\S+) (.*)$//) {
    return $self->infobot_reply($1, $2, $mess);
  }

  # these are all direct commands, and must be addressed.

  return unless $mess->{address};
  
  if ($body =~ /^forget\s+(.*)$/i) {
    if ( $self->delete_factoid($1) ) {
      return "I forgot about $1";
    } else {
      return "I don't know anything about $1";
    }
  }

  if ($body =~ /^ask\s+(\S+)\s+about\s+(.*)$/i) {
    $self->ask_factoid($2, $1, $mess);
    return "asking $1 about $2..\n";
  }

  if ($body =~ /^search\s+for\s+(.*)$/i) {
    return "privmsg only, please" unless $mess->{channel} eq "msg";
    my @results = $self->search_factoid(split(/\s+/, $1)) or return;
    $#results = 20 if $#results > 20;
    return "Keys: ".join(", ", map { "'$_'" } @results);
  }

}

sub fallback {
  my ($self, $mess) = @_;
  my $body = $mess->{body};

  # fallback - passively learn things and answer questions.
  
  if ( $body =~ s/\?+$// and ( $mess->{address} or $self->get("user_passive_answer") ) ) {
    # literal question?
    my $literal = 1 if ($body =~ s/^literal\s+//i);

    # get the factoid, and the type of relationship
    my ($is_are, $factoid) = $self->get_factoid($body, $literal);

    # if there's no such factoid, we give up.
    unless ($factoid) {
      return $mess->{address} ? "No clue. Sorry." : undef;
    }

    # emote?
    if ($factoid =~ s/^<action>\s*//i) {
      $self->bot->emote({
        who => $mess->{who},
        channel => $mess->{channel},
        body => $factoid
      });
      return 1;

    } elsif ($factoid =~ s/^<reply>\s*//i) {
      # a straight reply
      return $factoid;

    } else {
      # normal factoid
      return "$body $is_are $factoid";

    }

  }

  # the only thing left is learning factoids. are we addressed? Or
  # are we willing to learn passively?
  return unless ( $mess->{address} or $self->get("user_passive_learn") );

  # does it even look like a factoid?
  return unless ($body =~ /^(.*?)\s+(is)\s+(.*)$/i or $body =~ /^(.*?)\s+(are)\s+(.*)$/i);

  my ($object, $is_are, $description) = ($1, $2, $3);

  # allow corrections and additions.
  my $replace = 1 if ($object =~ s/no,?\s*//i);
  my $also = 1 if ($description =~ s/^also\s+//i);

  # long factoid keys are almost _always_ wrong.
  # TODO - this should be a user variable
  return if length($object) > 25;

  # certain words can't ever be factoid keys, to prevent insanity.
  my @stopwords = split(/\s*[\s,]\s*/, $self->get("user_stopwords") || "");
  for (@stopwords) {
    return if $object =~ /\Q$_/;
  }

  # if we're replacing things, remove it first.
  if ($replace) {
    $self->delete_factoid($object);
  }

  # get any current factoid there might be.
  my ($type, $current) = $self->get_factoid($object);
  
  # we can't add without explicit instruction, but shouldn't warn if this is passive.
  if ($current and !$also and $mess->{address}) {
    return "... but $object $type $current ...";
  } elsif ($current and !$also and !$mess->{address}) {
    return undef;
  }

  $self->add_factoid($object, $is_are, split(/\s+or\s+/, $description) );

  # return an ack if we were addressed only
  return $mess->{address} ? "okay." : 1;
}

sub get_factoid {
  my ($self, $object, $literal) = @_;
  
  # get a list of factoid hashes
  my ($is_are, @factoids) = $self->get_raw_factoids($object, $literal);

  # simple is a list of the 'simple' factoids, a is b, etc. These are just
  # joined together. Alternates are factoids that are an alternative to
  # the simple factoids, they will randomly be displayed _instead_.
  my (@simple, @alternatives);

  for (@factoids) {
    if ($_->{alternate}) {
      push @alternatives, $_->{text};
    } else {
      push @simple, $_->{text};
    }
  }

  if ($literal) {
    # we want a literal string describing the factoids entirely, with
    # explicit joins between the seperate atoms. We indicate alternatives
    # with a '|', similarly to the 'real' infobot.
    return ("=${is_are}=", join (" =or= ",
                                 @simple, map { "|$_" } @alternatives
                                )
           );
  }
  
  # the simple list is one of the alternatives
  unshift @alternatives, join(" or ", @simple);

  # pick an option at random
  my $factoid = $alternatives[ rand(@alternatives) ];

  # if there are any RSS directives, get the feed.
  # TODO - this could be done in a more general way, with plugins
  # TODO - this blocks. Bad. you can knock the bot off channel by
  # giving it an RSS feed that'll take a very long time to return.
  $factoid =~ s/<(?:rss|atom|feed|xml)\s*=\s*\"?([^>\"]+)\"?>/$self->parseFeed($1)/ieg;

  return ($is_are, $factoid);
}

# for a given key, return the raw hashes that are in the store for this
# factoid.
sub get_raw_factoids {
  my ($self, $object) = @_;
  my $raw = $self->get( "infobot_".lc($object) )
    or return ();

  my ($is_are, @factoids);

  if (ref($raw)) {
    # it's a deep structure
    $is_are = $raw->{is_are};
    @factoids = @{ $raw->{factoids} || [] };

  } else {
    # old-style tab seperated thing
    my @strings;
    ($is_are, @strings) = split(/\t/, $raw);
    for my $text (@strings) {
      my $alt = ($text =~ s/^\|\s*// ? 1 : 0);
      push @factoids, { alternate => $alt, text => $text };
    }
  }

  return ($is_are, @factoids);
}

sub add_factoid {
  my ($self, $object, $is_are, @factoids) = @_;

  # get the current list, if any
  my ($current_is_are, @current) = $self->get_raw_factoids($object);
  
  # if there's already an is_are set, use it.
  $is_are = $current_is_are if ($current_is_are);
  $is_are ||= "is"; # defaults

  # add these factoids to the list, trimming trailing space after |
  for (@factoids) {
    my $alt = s/^\|\s*// ? 1 : 0;
    push @current, {
      alternate => $alt,
      text => $_,
    };
  }

  my $set = {
    is_are => $is_are,
    factoids => \@current,
  };

  # put the list back into the store.
  $self->set( "infobot_".lc($object), $set);
  
  
  return 1;
}

sub delete_factoid {
  my ($self, $object) = @_;
  $self->unset( "infobot_".lc($object) );
  return 1;
}

sub ask_factoid {
  my ($self, $object, $ask, $mess) = @_;

  # unique ID to reference this in future
  my $id = "<" . int(rand(100000)) . ">";

  # store the message, so we can reply in context later
  $self->{remote_infobot}{$id} = $mess;

  # ask, using an infobot protocol, the thing we've been told to ask.
  # this will hopefully result in a reply coming back later.
  $self->bot->say(
    who => $ask,
    channel=>'msg',
    body=>":INFOBOT:QUERY $id $object"
  );
}

sub search_factoid {
  my ($self, @terms) = @_;
  my @keys = map { s/^infobot_// ? $_ : () } $self->store_keys;
  for my $term (@terms) {
    @keys = grep { /\Q$term/ } @keys;
  }
  return @keys;
}


sub parseFeed {
    my ($self, $url) = @_;

    my @items;
    eval {
        my $feed = XML::Feed->parse( URI->new( $url ) );
        @items = map { $_->title } $feed->entries;
    };

    return "<< Error parsing RSS from $url: $@ >>" if $@;
    my $ret;
    foreach my $title (@items) {
        $title =~ s/\s+/ /;
        $title =~ s/\n//g;
        $title =~ s/\s+$//;
        $title =~ s/^\s+//;
        $ret .= "${title}; ";
    }
    $ret =~ s/\s*$//;
    return $ret;
}

# We've been replied to by an infobot.
sub infobot_reply {
  my ($self, $id, $return, $mess) = @_;

  # get the message that caused the ask initially, so we can reply to it
  # if there wasn't one, just give up.
  my $infobot_data = $self->{remote_infobot}{$id} or return 1;

  # this is the string that the other infobot returned to us.
  my ($object, $db, $factoid) = ($return =~ /^(.*) =(\w+)=> (.*)$/);

  $self->set_factoid($mess->{who}, $object, $db, $factoid);

  # reply to the original request saying 'we got it'
  $self->bot->say(
    channel => $infobot_data->{channel},
    who     => $infobot_data->{who},
    body    => "Learnt about $object from $mess->{who}",
  );

  return 1;

}

1;
