use strict;
use warnings;

use Test;

BEGIN { 
    if( not -f "test_simplex" ) {
        plan tests => 1;
        print "# skipping all tests, not installing SimpleX\n";
        skip(1,1,1);
        exit 0;
    }
}

use Net::IMAP::SimpleX;

plan tests => our $tests = 3 + 6;

sub run_tests {
    open INFC, ">>", "informal-imap-client-dump.log" or die $!;

    my $imap = Net::IMAP::SimpleX->new('localhost:8000', debug=>\*INFC, use_ssl=>1)
        or die "\nconnect failed: $Net::IMAP::Simple::errstr\n";

    $imap->login(qw(working login));
    my $nm = $imap->select('INBOX')
        or die " failure selecting INBOX: " . $imap->errstr . "\n";

    $imap->put( INBOX => "Subject: test" );

    my $bs = $imap->body_summary(1);
    ok( int(@{ $bs->{parts} }), 1 );
    ok( $bs->{type}, "SINGLE" );
    ok( $bs->{parts}[0]{content_type}, "text/plain" );

    $imap->put( INBOX => <<TEST2 );
From jettero\@cpan.org Wed Jun 30 11:34:39 2010
Subject: something
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="0-1563833763-1277912078=:86501"

--0-1563833763-1277912078=:86501
Content-Type: text/plain; charset=fake-charset-1

Text Content.

--0-1563833763-1277912078=:86501
Content-Type: text/html; charset=fake-charset-2

<p>HTML Content</p>

--0-1563833763-1277912078=:86501--

TEST2

    $bs = $imap->body_summary(2);
    ok( int(@{ $bs->{parts} }), 2 );
    ok( $bs->{type}, "alternative" );
    ok( $bs->{parts}[0]{content_type}, "text/plain" );
    ok( $bs->{parts}[1]{content_type}, "text/html" );
    ok( $bs->{parts}[0]{charset}, "fake-charset-1" );
    ok( $bs->{parts}[1]{charset}, "fake-charset-2" );
}

do "t/test_server.pm" or die "error starting imap server: $!$@";