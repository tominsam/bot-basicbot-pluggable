package Bot::BasicBot::Pluggable::Module::Blog;
use Bot::BasicBot::Pluggable::Module::Base;
use base qw(Bot::BasicBot::Pluggable::Module::Base);

=head1 NAME

Bot::BasicBot::Pluggable::Module::Blog

=head1 SYNOPSIS

Chump-like blogging engine. somewhat specialist. See http://2lmc.org/blog
for an example of it's use. This requires a mysql datyabase back-end.

Will require some hacking to make work. Sorry.

=head1 IRC USAGE

Commands are:

=over 4

=item blog <text>

Creates a new blog entry and makes it current.

=item chump <text>

Creates a new blog entry, makes it current, and will say the id of the just
created entry.

=item bc <text>

Add a comment to the last blog entry

=item <number>: <text>

Comment on the entry with blog_id <number>. Can be a blog_id or a timestamp.

=item unblog <entry>

Removes a blog entry. say 'unblog last' to remove the last-blogged entry.
'entry' can be a blog_id or a timestamp.

=item showblog <id>

Shows the contents of the given blog entry.
'id' can be a blog_id, a timestamp, or 'last'.

=item searchblog <terms>

Searches blog entries for the given text.

=back

=head1 VARS

=over 4

=item db_name

local mysql database name for chumping to go into.

=item db_user

username to connect to database

=item db_pass

password to connect to database. Stored in the bot in cleartext and can be
got by anyone with a bot login, beware.

=back

=head1 USING THE OUTPUT

See the web page code in the examples/ folder

=head1 TODO

=cut


use DBI;

sub help {
    my ($self, $mess) = @_;

    return "Blogger for Bot::BasicBot::Pluggable. Usage: blog <text>, bc <text>, various chump-like grammars. delete entries with 'unblog'";
}

sub init {
    my $self = shift;

    # the Blog module requires a mysql database
    my $dsn = "DBI:mysql:database=$self->{store}{vars}{db_name}";
    my $user = $self->{store}{vars}{db_user};
    my $pass = $self->{store}{vars}{db_pass};

    $self->{DB} = DBI->connect($dsn, $user, $pass)
        or warn "Can't connect to database";

}

sub said {
    my ($self, $mess, $pri) = @_;

    return unless ($pri == 2);

    my $body = $mess->{body};

    if ($body =~ /^(\d+):\s*(.*)$/) {
        $body = "blogcomment $1 $2";
    }

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);
    $command =~ s/:+$//;

    if ($command eq "blog" or $command eq "spool") {
        my $query = $self->{DB}->prepare("INSERT INTO mindblog (timestamp, entry_type, channel, who, data) VALUES (?, ?, ?, ?, ?)");
        $query->execute(time, 1, $mess->{channel}, $mess->{who}, $param);
        $self->{blog_id} = $self->{DB}->{mysql_insertid};
        return 1;

    } elsif ($command eq "chump") {
        my $query = $self->{DB}->prepare("INSERT INTO mindblog (timestamp, entry_type, channel, who, data) VALUES (?, ?, ?, ?, ?)");
        $query->execute(time, 1, $mess->{channel}, $mess->{who}, $param);
        $self->{blog_id} = $self->{DB}->{mysql_insertid};
        return "chump $self->{blog_id}";

    } elsif ($command eq "bc") {
        if ($self->{blog_id}) {
            do {} while ($param =~ s/^\s*bc\s+//i);
            $self->comment($self->{blog_id}, $mess->{who}, $param);
            return 1;
        } else {
            return "I can't comment - I don't know what the last blog entry was.";
        }

    } elsif ($command eq "blogcomment") {
        my ($blog_id, $param) = split(/\s/, $param, 2);
        if ($blog_id) {
            $self->comment($blog_id, $mess->{who}, $param);
            return 1;
        } else {
            return "Comment on what?";
        }

    } elsif ($command eq "unblog" and $mess->{address}) {
        if ($param =~ /(\d{8,})/) {
            # timestamp
            my $query = $self->{DB}->prepare("DELETE FROM mindblog WHERE timestamp=?");
            $query->execute($1);
            $self->{blog_id} = undef;
            return "Deleted blog entry with timestamp $1";
        
        } elsif ($param =~ /(\d+)/) {
            # Blog ID
            my $query = $self->{DB}->prepare("DELETE FROM mindblog WHERE blog_id=?");
            $query->execute($1);
            $self->{blog_id} = undef;
            return "Deleted blog entry with blog_id $1";

        } elsif (lc($param) eq "last") {
            if ($self->{blog_id}) {
                my $query = $self->{DB}->prepare("DELETE FROM mindblog WHERE blog_id=?");
                $query->execute($self->{blog_id});
                $self->{blog_id} = undef;
                return "Deleted last blog entry";
            } else {
                return "Sorry, I lost track of the last blog entry.";
            }

        } else {
            return "Delete by timestamp, blog_id, or 'last'.";

        }

    } elsif (($command eq "showblog" or $command eq "blogshow") and $mess->{address}) {

        my $query;
        if ($param =~ /(\d{8,})/) {
            # timestamp
            $query = $self->{DB}->prepare("SELECT * FROM mindblog WHERE timestamp=?");
            $query->execute($1);

        } elsif ($param =~ /(\d+)/) {
            # Blog ID
            $query = $self->{DB}->prepare("SELECT * FROM mindblog WHERE blog_id=?");
            $query->execute($1);

        } elsif (lc($param) eq "last") {
            if ($self->{blog_id}) {
                $query = $self->{DB}->prepare("SELECT * FROM mindblog WHERE blog_id=?");
                $query->execute($self->{blog_id});
            } else {
                return "Sorry, I lost track of the last blog entry.";
            }

        } else {
            return "Show by timestamp, blog_id, or 'last'.";
        }

        if (my $row = $query->fetchrow_hashref) {
            return "blog_id=$row->{blog_id}, timestamp=$row->{timestamp}, who=$row->{who}, data=$row->{data}";
        } else {
            return "Can't find it, sorry";
        }

    } elsif (($command eq "searchblog" or $command eq "blogsearch") and $mess->{address}) {
        my ($search) = ($param =~ /(\w+)/);
        my $limit = ($mess->{channel} eq "msg" ? 20 : 3);

        my $query = $self->{DB}->prepare("SELECT DISTINCT mindblog.* "
                                       . "FROM mindblog,mindblog_comments "
                                       . "WHERE mindblog.blog_id=mindblog_comments.blog_id "
                                       . "AND (mindblog.data LIKE '%$search%' "
                                       . "OR mindblog_comments.data LIKE '%$search%') "
                                       . "ORDER BY timestamp DESC");
        $query->execute();
        my $i = $limit;
        my $reply = "Search for '$search'\n";
        while ($i and my $row = $query->fetchrow_hashref) {
            $reply .= "($row->{blog_id}) $row->{who}: $row->{data}\n";
            $i--;
        }    
        return $reply;
    }

    return undef;
}

sub comment {
    my ($self, $id, $who, $body) = @_;
    my $query = $self->{DB}->prepare("INSERT INTO mindblog_comments (blog_id, timestamp, who, data) VALUES (?, ?, ?, ?)");
    $query->execute($id, time, $who, $body);
    $query = $self->{DB}->prepare("SELECT COUNT(comment_id) as comments FROM mindblog_comments WHERE blog_id=?");
    $query->execute($id);
    my $count = $query->fetchrow_hashref()->{comments};
    print STDERR "There are $count comments now\n";
    if ($count > 4) {
        break unless my $tb = $self->{Bot}->handler('Trackback');

        print STDERR "Trying trackbacks\n";
        my $query = $self->{DB}->prepare("SELECT data FROM mindblog WHERE blog_id=?");
        $query->execute($id);
        my $data = $query->fetchrow_hashref()->{data};

        my $comments_query = $self->{DB}->prepare("SELECT data FROM mindblog_comments WHERE blog_id=?");
        $comments_query->execute($id);
        my $d;
        $data .= " $d->{data}" while ($d = $comments_query->fetchrow_hashref());

        while ($data =~ s!(http://[^\s\|\"\>\]]+)!!) {
            print STDERR $tb->send_ping($1, $id)."\n";
        }        
    }
}

1;
