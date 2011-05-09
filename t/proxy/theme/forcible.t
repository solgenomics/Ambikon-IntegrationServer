use strict;
use warnings;

use Test::More;

use lib 't/lib';
use Ambikon::IntegrationServer::Test::Proxy qw/ test_proxy /;

sub forcible_conf {

    my $force_site = $ENV{FORCE_EXTERNAL_SITE} || 'http://$host:$port2/monkeys';

    my $conf = <<'EOC'
theme_from_subsite  mainsite

<subsite mainsite>
  internal_url   http://$host:$port1
  external_path  /

  <Theme::ForcibleTemplate>
      theme_url /ambikon_theme
  </Theme::ForcibleTemplate>

</subsite>
<subsite foo_bar>
EOC
."  internal_url $force_site\n"
.<<'EOC'

  external_path  /foo

  <modify>
      when content_type:text/html
      with Theme::ForcibleTemplate

      <Theme::ForcibleTemplate>
          theme_from_subsite mainsite
      </Theme::ForcibleTemplate>
  </modify>
</subsite>
EOC
    ;
    return $conf;
}

# test a basic conf with 1 backend
test_proxy(
    conf => forcible_conf(),
    backends => [
        sub {
            my $env = shift;

            return [
                200,
                ['Content-type' => 'text/html'],
                [ <<'EOTHEME' ],
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <link rel="stylesheet" href="/fictitious/stylesheet.css" />
    <script language="javascript" type="text/javascript">
      JSAN = {};
      JSAN.use = function() {};
      MochiKit = {__export__: false};
    </script>
  </head>
  <body>
    <div id="outercontainer">
      <!-- hi i'm a comment -->
      <a name="top"></a>
      <table id="siteheader" cellpadding="0" cellspacing="0">
        <td>foo</td><td>tool</td><td>bar</td>
      </table>

      <!-- AMBIKON_CONTENT -->

      <!-- and this is another comment -->
   </div>
  </body>
</html>
EOTHEME
              ];
        },
        sub {
            my $env = shift;

            my %dispatch = (
                '/monkeys/' => [
                    200,
                    [ 'Content-type' => 'text/html',
                      'X-bar'  => 'fogbat',
                      'X-zee'  => 'zaz',
                    ],
                    [ slurp( 't/data/unmodified_1.html' )]],
              );

            return $dispatch{ $env->{PATH_INFO} } || [ 404, [], [$env->{PATH_INFO}.' not found']];;
        },
      ],

    client => sub {
        my $mech = shift;
        $mech->get_ok( '/foo/' );
        $mech->content_contains('Tomato Functional') unless $ENV{FORCE_EXTERNAL_SITE};
        $mech->content_lacks('&lt;', 'no funny quoting' );
        $mech->content_contains( '<link rel="stylesheet" href="/fictitious/stylesheet.css" />', 'got template head' );
        $mech->content_contains( '<div id="outercontainer">', 'got template body start' );
        $mech->content_contains( 'and this is another comment', 'got template body end' );
        $mech->content_contains('</html>');
        my $count = $mech->content =~ m!</html>!g;
        is( $count, 1, 'only one closing html' );
        diag $mech->content if $ENV{FORCE_EXTERNAL_SITE};
    },
  );

done_testing;
exit;

sub slurp {
    my $f = shift;
    open my $h, '<', $f or die "$! reading $f";
    local $/;
    return <$h>;
}

