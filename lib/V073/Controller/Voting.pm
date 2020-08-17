package V073::Controller::Voting;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub create_voting_form ($self) {
    # Template only
}

sub create_voting ($self) {

    # Use default options
    my $type = $self->db('Type')->first;

    # Create
    my $voting = $self->db('Voting')->create({
        text    => $self->param('text'),
        type    => $type->name,
        token   => $self->token,
    });

    # Save & redirect
    $self->session(voting => $voting->id);
    return $self->redirect_to('voting');
}

sub restricted ($self) {

    # Nothing found in session data
    my $voting_id = $self->session('voting');
    $self->reply->not_found and return unless defined $voting_id;

    # Try to load
    my $voting = $self->db('Voting')->search({id => $voting_id})->first;
    $self->reply->not_found and return unless defined $voting;

    # Store
    $self->stash(voting => $voting);
}

sub view ($self) {

    # Calculate vote counts by option
    my $voting  = $self->stash('voting');
    my $options = $voting->type->options;
    my %ov      = ();
    for my $option ($options->all) {
        $ov{$option->id} = $option->votes({voting => $voting->id})->count;
    }

    # Done
    $self->stash(
        voting              => $voting,
        options             => $options,
        option_vote_counts  => \%ov,
    );
}

sub generate_tokens ($self) {

    # Check token count
    my $count = $self->param('token_count');
    $count =~ s/^\s*(\S+)\s*$/$1/;
    return $self->render(text => 'Invalid token count', status => 403)
        if $count =~ /\D/ or $count < 1 or $count > 1_000;

    # Generate and store tokens
    for my $i (1 .. $count) {
        my $token = $self->token; # Generate
        $self->stash('voting')->create_related(tokens => {name => $token});
    }

    # Done
    return $self->redirect_to('voting');
}

1;
