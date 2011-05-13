package Ambikon::IntegrationServer::Role::SubsiteModifier;
use Moose::Role;

sub will_modify_response { 1 }

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

before 'modify_response' => sub {
    my ( $self, $c ) = @_;

    # any postprocessing is likely to make the original content length
    # wrong.  If we undef it here, Catalyst will recalculate it for us
    # when it actually sends the response.
    $c->res->headers->remove_header('Content-Length');
};

sub modify_request  {}
sub modify_response {}
sub can_stream      { 0 }

1;
