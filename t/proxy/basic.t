use strict;
use warnings;

use Test::More;
use Test::TCP;

use IO::String;
use Plack::Loader;

use lib 't/lib';
use amb_int_mech;

my $host = '127.0.0.1';
test_tcp(
    client => sub {
        my ( $port, $server_pid ) = @_;

        my $mech = amb_int_mech->new( configuration => <<"" );
<subsite foo_bar>
  internal_url   http://$host:$port/monkeys
  external_path  /foo
</subsite>

        $mech->get_ok( '/foo/bar/baz' );
        $mech->content_contains( 'Hello world' );
        $mech->dump_headers;
    },
    server =>  sub {
        my ( $port ) = @_;
        local $ENV{PLACK_SERVER} = 'Standalone';
        my $server = Plack::Loader->auto( port => $port, host => $host );
        my $hello = "Hello world\n";
        $server->run(sub {
            return [ 200, [ 'Content-type','text/html','Content-length', length $hello ], IO::String->new( \$hello ) ];
        });
    },
);


done_testing;
