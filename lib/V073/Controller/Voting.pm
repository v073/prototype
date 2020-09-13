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

    # Generate initial tokens
    my $count = $self->param('token_count');
    $count =~ s/^\s*(\S+)\s*$/$1/;
    return $self->render(text => 'Invalid token count', status => 403)
        if $count =~ /\D/ or $count < 0
        or $count > $self->config('voting')->{max_token_count};
    for my $i (1 .. $count) {
        my $token = $self->token; # Generate
        $voting->create_related(tokens => {name => $token});
    }

    # Save & redirect
    $self->session(voting => $voting->id);
    return $self->redirect_to('admin_token');
}

sub restricted ($self) {

    # Nothing found in session data
    my $voting_id = $self->session('voting');
    $self->reply->not_found and return unless defined $voting_id;

    # Try to load
    my $voting = $self->db('Voting')->search({'me.id' => $voting_id},
        {prefetch => {type => 'options'}})->first;
    $self->reply->not_found and return unless defined $voting;

    # Store
    $self->stash(
        voting  => $voting,
        options => scalar($voting->type->options),
    );
}

sub admin_token ($self) {
    # Template only
}

sub view ($self) {

    # Closed: show the results
    my $voting = $self->stash('voting');
    if ($voting->closed) {

        # Count
        my $vote_total  = $voting->votes->count;
        my $token_total = $voting->tokens->count;
        my %count; $count{$_->get_column('option')}++ for $voting->votes;
        # $_->option->id would lead to a new request

        # Done
        return $self->render(
            vote_count  => \%count,
            vote_total  => $vote_total,
            token_total => $token_total,
            template    => 'vote/results',
        );
    }

    return $self->render(template => 'voting/view');
}

sub generate_tokens ($self) {

    # Check token count
    my $count = $self->param('token_count');
    $count =~ s/^\s*(\S+)\s*$/$1/;
    return $self->render(text => 'Invalid token count', status => 403)
        if $count =~ /\D/ or $count < 1
        or $count > $self->config('voting')->{max_token_count};

    # Generate and store tokens
    for my $i (1 .. $count) {
        my $token = $self->token; # Generate
        $self->stash('voting')->create_related(tokens => {name => $token});
    }

    # Done
    return $self->redirect_to('voting');
}

sub delete_token ($self) {

    # Prepare
    my $voting      = $self->stash('voting');
    my $token_name  = $self->param('token');

    # Delete
    my $deleted = $voting->delete_related(tokens => {name => $token_name});
    return $self->reply->not_found unless $deleted;

    # Done
    return $self->redirect_to('voting');
}

sub start ($self) {

    # Prepare
    my $voting      = $self->stash('voting');
    my $token_count = $voting->tokens->count;

    # Forbidden state to start the voting?
    return $self->render(text => 'Forbidden', status => 403)
        if $token_count <= 0;

    # OK, start
    $self->stash('voting')->update({started => 1});
    return $self->redirect_to('voting');
}

sub close ($self) {

    # Prepare
    my $voting      = $self->stash('voting');
    my $token_count = $voting->tokens->count;

    # Forbidden state to close the voting?
    return $self->render(text => 'Forbidden', status => 403)
        if not $voting->started;

    # OK, close
    $self->stash('voting')->update({closed => 1});
    return $self->redirect_to('voting');
}

1;
