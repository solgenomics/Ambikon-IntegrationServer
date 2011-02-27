package App::Ambikon::Subsite;
# ABSTRACT: object representing an Ambikon subsite
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::URI 'Uri';

=attr shortname

Shortname of the subsite, with no whitespace.

=cut

has 'shortname' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
  );

=attr name

Optional longer name of the subsite.  Defaults to value of C<shortname>.

=cut

has 'name' => (
    is => 'ro',
    isa => 'Str',
    default => sub { shift->shortname },
);

=attr internal_url

The base URL where Ambikon will access this subsite.

=cut

has 'internal_url' => (
    is       => 'ro',
    isa      => Uri,
    coerce   => 1,
    required => 1,
);

=attr external_path

Relative path where this subsite is accessed.

=cut

subtype 'AmbExternalPath'
    => as 'Str'
    => where { $_ =~ m!^/! }
    => message { "invalid external_path '$_': it must be a URL path relative to the site root, e.g. '/gbrowse'" };

has 'external_path' => (
    is       => 'ro',
    isa      => 'AmbExternalPath',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
