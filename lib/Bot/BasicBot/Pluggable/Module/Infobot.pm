=head1 NAME

Bot::BasicBot::Pluggable::Module::Infobot

=head1 SYNOPSIS

Does infobot things - basically remmebers and returns factoids. Will ask
another infobot about factoids that it doesn't know about, if you want.

=head1 IRC USAGE

Assume the bot is called 'eric'. Then you'd use the infobot as follows.

  me: eric, water is wet.
  eric: Ok, water is wet.
  me: water?
  eric: water is wet.
  me: eric, water is also blue.
  eric: ok, water is also blue.
  me: eric, water?
  eric: water is wet or blue.
  
etc, etc.

a response that begins <reply> will have the '<noun> is' stripped, so

  me: eric, what happen is <reply>somebody set us up the bomb
  eric: ok, what happen is <reply>somebody set us up the bomb.
  me: what happen?
  eric: somebody set us up the bomb

just don't do that in #london.pm.

Likewise, a response that begins <action> will be emoted as a response,
instead of said. Putting '|' characters in the reply indicates different
possible answers, and the bot will pick one at random.

  me: eric, dice is one|two|three|four|five|six
  eric: ok, dice is one|two|three|four|five|six
  me: eric, dice?
  eric: two.
  me: eric, dice?
  eric: four.
  
Finally, you can read RSS feeds:

  me: eric, jerakeen.org is <rss="http://jerakeen.org/index.rdf">
  eric: ok, jerakeen.org is...
  
ok, you get the idea.

You can also tell the bot to learn a factoid from another bot, as follows:

  me: eric, learn fact from dispy
  eric: learnt 'fact is very boring' from dipsy.
  me: fact?
  eric: fact is very boring
  
=head1 VARS

=over 4

=item ask

Set this to the nick of an infobot and your bot will ask them about factoids
that we don't know about, and forward them on (with attribution).

=back

=head2 TODO

If we need to request an RSS feed that takes a long time to come back, we'll
time out and drop off the server. oops.


=cut

package Bot::BasicBot::Pluggable::Module::Infobot;
use Bot::BasicBot::Pluggable::Module;
use base qw(Bot::BasicBot::Pluggable::Module);

use XML::RSS;
use LWP::Simple ();
use strict;
use warnings;

sub init {
    my $self = shift;
    for (qw( ask passive_ask passive_learn stopwords )) {
      $self->set("user_$_" => "") unless defined($self->get("user_$_"));
    }
    $self->{remote_infobot} = {};
}

# TODO
sub help {
  return "ooooooh, infobots. They're hard. ".
  "See http://search.cpan.org/perldoc?Bot::BasicBot::Pluggable::Module::Infobot";
}

sub said {
    my ($self, $mess, $pri) = @_;

    my $body = $mess->{body};
    $body =~ s/\s+$//;
    $body =~ s/^\s+//;
    
    if ($body =~ s/^:INFOBOT:REPLY (\S+) (.*)$// and $pri == 0) {
        my $return = $2;
        my $infobot_data = $self->{remote_infobot}{$1};
        my ($object, $db, $factoid) = ($return =~ /^(.*) =(\w+)=> (.*)$/);

        if ($infobot_data->{learn}) {
            $self->set_factoid($mess->{who}, $object, $db, $factoid);
            $factoid = "Learnt about $object from $mess->{who}"; # hacky.

        } else {

            my @possibles = split(/(?:=?or=?\s*)\|\s*/, $factoid);
            $factoid = $possibles[int(rand(scalar(@possibles)))];

            $factoid =~ s/<rss\s*=\s*\"?([^>\"]+)\"?>/$self->parseRSS($1)/ieg;

            if ($factoid =~ s/^<action>\s*//i) {
                $self->bot->emote({who=>$infobot_data->{who}, channel=>$infobot_data->{channel}, body=>"$factoid (via $mess->{who})"});
                return 1;
            }

           $factoid = "$object $db $factoid" unless ($factoid =~ s/^<reply>\s*//i);

            return unless $factoid;
            $factoid .= " (via $mess->{who})";


        }
        
        my $shorter;
        while ($factoid) {
            $shorter .= substr($factoid, 0, 300, "");
        }

        $self->bot->say(channel => $infobot_data->{channel},
                          who     => $infobot_data->{who},
                          body    => "$_"
                         ) for (split(/\n/, $shorter));
        return 1;
    }

    if ( $body =~ s/\?+$// and ( $mess->{address} or $self->get("user_passive_ask") ) and $pri == 3) {
        my $literal = 1 if ($body =~ s/^literal\s+//i);

        my $factoid;
        unless ($factoid = $self->get_factoid($body, $mess)) {
            return undef unless $mess->{address};
            return "No clue. Sorry.";
        }

        return "$body =$factoid->{is_are}= $factoid->{description}" if $literal;

        my @possibles = split(/(?:=?or=?\s*)\|\s*/, $factoid->{description});
        my $reply = $possibles[int(rand(scalar(@possibles)))];

        $reply =~ s/<rss\s*=\s*\"?([^>\"]+)\"?>/$self->parseRSS($1)/ieg;

        if ($reply =~ s/^<action>\s*//i) {
            $self->bot->emote({
                who=>$mess->{who},
                channel=>$mess->{channel},
                body=>$reply
            });
            return 1;
        }

        $reply = "$body $factoid->{is_are} $reply" unless ($reply =~ s/^<reply>\s*//i);
        return $reply;
    }

    if ($pri==2 and $mess->{address} and $body =~ /^forget\s+(.*)$/i) {
        if ($self->delete_factoid($mess->{who}, $1)) {
            return "I forgot about $1";
        } else {
            return "I don't know anything about $1";
        }
    }
    if ($pri==2 and $mess->{address} and $body =~ /^ask\s+(\w+)\s+about\s+(.*)$/i) {
        $mess->{learn} = 1;
        if ($self->get_factoid($2, $mess, $1)) {
            return "I already know about $2";
        }
        return "asking $1 about $2..\n";
    }

    if ($pri==2 and $mess->{address} and $body =~ /^search\s+for\s+(.*)$/i) {
        return "privmsg only, please" unless $mess->{channel} eq "msg";
        my @results = $self->search_factoid(split(/\s+/, $1)) or return;
        return "Keys: ".join(", ", map { "'$_'" } @results);
    }


    return unless ($pri==3);
    return unless ( $mess->{address} or $self->get("user_passive_learn") );
    return unless ($body =~ /\s+(is)\s+/i or $body =~ /\s+(are)\s+/i);
    my $is_are = $1 or return;

    my ($object, $description) = split(/\s+${is_are}\s+/i, $body, 2);

    # long factoid keys are almost _always_ wrong.
    return if length($object) > 25;

    my $replace = 1 if ($object =~ s/no,?\s*//i);

    my @stopwords = split(/\s*,?\s*/, $self->get("user_stopwords") || "");
    return if grep(/^\Q$object$/i, @stopwords);
                
    if (my $old_factoid = $self->get_factoid($object)) {
        if ($description =~ s/^also\s+//i) {
            $description = $old_factoid->{description} .= " or ".$description;
        } elsif (!$replace) {
            return 1 unless $mess->{address};
            return "but I already know something about $object";
        }
    }
    
    $self->set_factoid($mess->{who}, $object, $is_are, $description);
    return 1 unless $mess->{address};
    return "ok."; # $object $is_are $description";

}

sub get_factoid {
    my ($self, $object, $mess, $from) = @_;

    my $factoid;
    if ($factoid = ( $self->get( "infobot_".lc($object) ) || [] )->[-1]
       and $factoid->{description} ) {
        return $factoid;
    }

    my $to_ask = $from || $self->get("user_ask");
    if ($to_ask and $mess) {
        my $id = "<" . int(rand(10000)) . ">";
        $self->{remote_infobot}{$id} = $mess;
        $self->bot->say(
            who => $to_ask,
            channel=>'msg',
            body=>":INFOBOT:QUERY $id $object"
        );
    }
    return undef;
}

sub search_factoid {
    my ($self, @terms) = @_;

    my $factoids = [];
    FACTOID: for my $key ( map { s/^infobot_// ? $_ : () } $self->store_keys ) {
      my $factoid = ( $self->get("infobot_$key") || [] )->[-1];
      next unless $factoid->{description};
      for (@terms) { next FACTOID unless $factoid->{object} =~ /$_/i }
      push @$factoids, $factoid->{object};
    }
    return @$factoids;
}

sub set_factoid {
    my ($self, $who, $object, $is_are, $description) = @_;
    my @factoids = @{$self->get("infobot_".lc($object) ) || [] };
    push(@factoids, {
        create_time => time,
        create_who => $who,
        object => $object,
        is_are => $is_are,
        description => $description,
    });
    $self->set( "infobot_".lc($object), \@factoids );
    return 1;
}

sub delete_factoid {
    my ($self, $who, $object) = @_;
    return 0 unless ($self->get_factoid($object));
    return $self->set_factoid($who, $object, undef, undef);
}

sub parseRSS {
    my ($self, $url) = @_;

    my $items;
    eval '
        my $rss = new XML::RSS;
        $rss->parse(LWP::Simple::get($url));
        $items = $rss->{items};
    ';

    return "<< Error parsing RSS from $url: $@ >>" if $@;
    my $ret;
    foreach my $item (@$items) {
        my $title = $item->{title};
        $title =~ s/\s+/ /;
        $title =~ s/\n//g;
        $title =~ s/\s+$//;
        $title =~ s/^\s+//;
        $ret .= "$item->{'title'}; ";
    }
    return $ret;
}


1;
