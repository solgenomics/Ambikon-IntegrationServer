package Ambikon::IntegrationServer::Role::SubsiteModifier;
use Moose::Role;

sub will_postprocess { 1 }

requires 'postprocess', 'can_stream';

has '_app' => (
    is       => 'ro',
    required => 1,
    weak_ref => 1,
);

has '_subsite' => (
    is       => 'ro',
    required => 1,
    weak_ref => 1,
    );

before 'postprocess' => sub {
    my ( $self, $c ) = @_;

    # any postprocessing is likely to make the original content length
    # wrong.  If we undef it here, Catalyst will recalculate it for us
    # when it actually sends the response.
    $c->res->headers->remove_header('content-length');
};

1;
