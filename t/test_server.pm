our $tests;

use strict;
use Net::TCP;
no warnings;

for my $mod (qw(Coro::EV Net::IMAP::Server IO::Socket::SSL)) {
    my $res = do {
        # NOTE: the imap server emits various startup warnings on import
        local $SIG{__WARN__} = sub {};
        eval "use $mod; 1";
    };

    unless( $res ) {
        warn "$mod not found, skipping all meaningful tests\n";
        skip(1,1,1) for 1 .. $tests;
        exit 0;
    }
}

$SIG{CHLD} = $SIG{PIPE} = sub {};

sub kill_imap_server {
    my $pid = shift;

    warn " killing: $pid";
    for(15,2,9,13,11) {
        kill $_, $pid;
        sleep 1;
    }
}

if( my $pid = fork ) {
    my $imapfh;
    my $retries = 10;

    my $line; {
        sleep 1 while (--$retries)>0 and not $imapfh = Net::TCP->new(localhost=>7000);

        if( not $imapfh ) {
            warn "unable to start Net::IMAP::Server, skipping all meaningful tests\n";
            skip(1,1,1) for 1 .. $tests;
            exit 0;
        } 

        $line = <$imapfh>;
        redo unless $line =~ m/OK/;
    };

    warn " imap server is up: $line";
    close $imapfh;

    $0 = "Net::IMAP::Simple($$)";

    run_tests();

    if( $imapfh = Net::TCP->new(localhost=>7000) ) {
        print $imapfh "1 Shutdown\n";
    }

    exit(0); # doesn't help, see below

} else {
    use POSIX qw(setsid); setsid();
    exit if fork; # setsid() can't save us, Coro hates exit(0) I
                  # guess seriously, without this line, the exit
                  # value after run_tests() will be non-zero, no
                  # matter what you pass to exit.

    $0 = "Net::IMAP::Server($$)";
    $SIG{ALRM} = sub {
        warn " $0, part of Net::IMAP::Simple tests, is comitting suicide ";
        kill_imap_server($$);
    };
    alarm 60;

    open my $pidfile, ">", "imap_server.pid" or die $!;
    print $pidfile "$$\n"; # the pid_file option for the server doesn't seem to work...
    close $pidfile;

    close STDOUT; close STDERR;
    unlink "informal-imap-server-dump.log";
    open STDERR, ">>informal-imap-server-dump.log";
    open STDOUT, ">>informal-imap-server-dump.log";
    # (we don't really care if the above fails...)

    use t7lib::Shutdown;
    Net::IMAP::Server->new(
        port        => 7000,
        ssl_port    => 8000,
        auth_class  => "t7lib::Auth",
        model_class => "t7lib::Model",
    )->run;
}

1;