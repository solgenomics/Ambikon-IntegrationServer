use strict;
use warnings;

use Test::More;
use Test::TCP;

use IO::String;
use Plack::Loader;

use lib 't/lib';
use amb_int_mech;

test_proxy(
    conf => <<'',
<subsite foo_bar>
  internal_url   http://$host:$port/monkeys
  external_path  /foo
</subsite>

    backend => sub {
        my $plack_server = shift;
        my $hello = "Hello world\n";
        $plack_server->run(sub {
            [ 200, [ 'Content-type','text/html','Content-length', length $hello ], IO::String->new( \$hello ) ];
        });
    },

    client => sub {
        my $mech = shift;

        $mech->get_ok( '/foo/bar/baz' );
        $mech->content_contains( 'Hello world' );
        $mech->dump_headers;
    },
  );

done_testing;
exit;

######## subroutines ######3

sub test_proxy {
    my %args = @_;

    my $host = $args{host} || '127.0.0.1';
    test_tcp(
        client => sub {
            my ( $port, $server_pid ) = @_;
            my $mech = amb_int_mech->new( configuration => eval qq|"$args{conf}"| );
            $args{client}->( $mech );
        },
        server =>  sub {
            my ( $port ) = @_;
            local $ENV{PLACK_SERVER} = 'Standalone';
            my $server = Plack::Loader->auto( port => $port, host => $host );
            $args{backend}->( $server );
        },
      );

}
