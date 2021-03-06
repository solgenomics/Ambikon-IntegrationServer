use strict;
use warnings;

use Test::More;
use Test::MockObject;

use Data::Dump 'dump';
use URI;

use aliased 'Ambikon::IntegrationServer::SubsiteModifier::RewriteURLs::HTML' => 'RewriteURLs';

my @tests;
my $c1 = {
    external_path => '/fog',
    internal_root => 'http://mickey.example.com:3000/abra/cadabra',
    ext_request   => 'http://logical.meltdown.com:235/fog/zook/battlestar.php',
    int_request   => 'http://mickey.example.com:3000/abra/cadabra/zook/battlestar.php',
};

push @tests, (
    [ $c1, '/abra/cadabra/ZIGGY/342',          '/fog/ZIGGY/342'                             ],
    [ $c1, 'calendar/bonk.cgi?foo=bar#fraggy', '/fog/zook/calendar/bonk.cgi?foo=bar#fraggy' ],
    [ $c1, ('http://example.com/someplace.do?ayee+oooo#honk') x 2                           ],
    );

my $c2 = {
    external_path => '/mickey/stardust.cgi',
    internal_root => 'http://mickey.localhost/foo',
    ext_request   => 'http://logical.meltdown.com/mickey/startdust.cgi/blarg/zook?zinc#L234',
    int_request   => 'http://mickey.localhost/foo/blarg/zook?zinc#L234',
};

push @tests, (
    [ $c2, '/foo', '/mickey/stardust.cgi' ],
    [ $c2, 'foo',  '/mickey/stardust.cgi/blarg/foo' ],
    [ $c2, 'http://mickey.localhost:80/foo/monkey/business.pl?x#f', '/mickey/stardust.cgi/monkey/business.pl?x#f' ],
    [ $c2, 'http://mickey.localhost/foo/monkey/business.pl?x#f', '/mickey/stardust.cgi/monkey/business.pl?x#f' ],
    [ $c2, ('ftp://mickey.localhost/foo/monkey/business.pl?x#f')x2 ],
    [ $c2, 'https://mickey.localhost/foo/monkey/business.pl?x#f', 'https://logical.meltdown.com/mickey/stardust.cgi/monkey/business.pl?x#f' ],
    [ $c2, ('http://bit.ly/2')x2 ],
    [ $c2, 'http://ca.ca', 'http://ca.ca' ],
    );

my $c3 = {
    external_path => '/zee',
    internal_root => 'http://mickey.localhost/ay',
    ext_request   => 'https://logical.meltdown.com/zee/zonk.pl',
    int_request   => 'http://mickey.localhost/ay/zee/zonk.pl',
};

push @tests, (
    [ $c3, '/ay/2',       '/zee/2'      ],
    [ $c3, '/v/sunk.php', '/v/sunk.php' ],
    [ $c3, '', '' ],
    [ $c3, undef, undef ],
    );

my $c4 = {
    external_path => '/foo',
    internal_root => 'https://mickey.localhost/bar',
    ext_request   => 'https://logical.meltdown.com/foo/zonk.php',
    int_request   => 'https://mickey.localhost/bar/zonk.php',
};

push @tests, (
    [ $c4, 'https://mickey.localhost/bar/1', '/foo/1' ],
    [ $c4, 'HTTPS://mickey.localhost/bar/1', '/foo/1' ],
    [ $c4, 'http://mickey.localhost/bar/1', 'http://logical.meltdown.com/foo/1'  ],
    );

my $c5 = {
    external_path => '/ted',
    internal_root => 'http://ted.bti.cornell.edu',
    ext_request   => 'http://logical.meltdown.com/ted',
    int_request   => 'http://ted.bti.cornell.edu',
};

push @tests, (
    [ $c5, '/TFGD/image/home_on.png', '/ted/TFGD/image/home_on.png' ],
    [ $c5, 'TFGD/image/home_on.png', '/ted/TFGD/image/home_on.png' ],
    );



rewrite_ok( @$_ ) for @tests;

done_testing;
exit;

###########

sub rewrite_ok {
  my ( $context, $in, $out ) = @_;
  my ( $internal_root, $external_path, $ext_request, $int_request ) =
    @{$context}{qw{ internal_root   external_path  ext_request  int_request }};

  my $mock_req = Test::MockObject->new;
  $mock_req->set_always( uri => URI->new( $ext_request ) );

  my $mock_c = Test::MockObject->new;
  $mock_c->set_isa('Ambikon::IntegrationServer');
  $mock_c->set_always( req => $mock_req );
  $mock_c->set_always( stash => { internal_url => URI->new( $int_request ) } );
  $mock_c->set_always( debug => mydebug->new );

  my $mock_ss = Test::MockObject->new;
  $mock_ss->set_isa('Ambikon::IntegrationServer::Subsite');
  $mock_ss->set_always( external_path => $external_path );
  $mock_ss->set_always( internal_url  => URI->new( $internal_root ) );

  my $r = RewriteURLs->new( _app => $mock_c, _subsite => $mock_ss );

  is( $r->rewrite_url_internal_to_external( $mock_c, $in ), $out, dump($in).' -> '.dump($out) );
  my ( $bi, $bo ) = do {
      no warnings 'uninitialized';
      qq|<a class="snogger" href =$in > "!!lkjdf<span></span> </a>|,
      qq|<a class="snogger" href =$out > "!!lkjdf<span></span> </a>|,
  };
  $r->_rewrite_tag_attr( $mock_c, \$bi, 'a', 'href' );
  is( $bi, $bo, 'tag rewriting works' );

}

BEGIN {
    package mydebug;
    sub new { bless {}, shift }
    sub warn { shift; warn @_ }
}
