use strict;
use warnings;

use Test::More;

use lib 't/lib';
use Ambikon::IntegrationServer::Test::Proxy qw/ test_proxy /;

# test a basic conf with 1 backend
test_proxy(
    conf => <<'EOC',
theme_from_subsite  mainsite

<subsite mainsite>
  internal_url   http://$host:$port1
  external_path  /

  <Theme::ForcibleTemplate>
      theme_url /ambikon_theme
  </Theme::ForcibleTemplate>

</subsite>
<subsite foo_bar>
  internal_url   http://$host:$port2/monkeys
  external_path  /foo

  <postprocess>
      when content_type:text/html
      with Theme::ForcibleTemplate

      <Theme::ForcibleTemplate>
          theme_from_subsite mainsite
      </Theme::ForcibleTemplate>
  </postprocess>
</subsite>

EOC

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
                '/monkeys/fog' => [
                    200,
                    [ 'Content-type' => 'text/html',
                      'X-bar'  => 'fogbat',
                      'X-zee'  => 'zaz',
                    ],
                    [ <<'EOH' ]],
<html>
  <head><title>This is my title, hihi!</title></head>
  <body><h1>Important Page</h1><p>This page is so important, you don't even <b>know</b>.</p></body>
</html>
EOH
              );

            return $dispatch{ $env->{PATH_INFO} } || [ 404, [], [$env->{PATH_INFO}.' not found']];;
        },
      ],

    client => sub {
        my $mech = shift;
        $mech->get_ok( '/foo/fog' );
        $mech->content_contains('so important');
        $mech->content_lacks( '$theme', 'templating was run' );
        $mech->content_lacks('&lt;', 'no funny quoting' );
        $mech->content_contains( '<link rel="stylesheet" href="/fictitious/stylesheet.css" />', 'got template head' );
        $mech->content_contains( '<div id="outercontainer">', 'got template body start' );
        $mech->content_contains( 'and this is another comment', 'got template body end' );
        $mech->html_lint_ok;
    },
  );

done_testing;
exit;

