package JobQueue::SharedMemory;
use 5.008005;
use strict;
use warnings;
use Cache::Isolator;
use Cache::SharedMemoryCache;
use Proc::Simple;
use Log::Minimal;
use Time::HiRes 'sleep';

our $VERSION = "0.01";

sub new {
    my ($class, %opts) = @_;
    my $max_jobs = delete $opts{max_jobs} || 10;
    $opts{namespace} ||= $class;
    my $cache = Cache::SharedMemoryCache->new({%opts});
    my $isolator = Cache::Isolator->new(cache => $cache, concurrency => 4);
    my $self = bless { cache => $isolator, max_jobs => $max_jobs }, $class;
    $self->_init_index;
    return $self;
}

sub _init_index {
    my $self = shift;
    $self->{cache}->get_or_set(index => sub { 1 });
}

sub _job {
    my ($self, $index) = @_;
    $self->{cache}->get('job'.$index);
}

sub enqueue {
    my ($self, $jobname, $data) = @_;
    my $index = $self->_job($self->_get_index) ? $self->_get_index + 1 : $self->_get_index;
    $self->{cache}->set('job'.$index, [$jobname, $data]);
}

sub dequeue {
    my ($self, $jobname) = @_;
    my $job;
    for my $i ( 1 .. $self->{max_jobs} ) {
        $job = $self->_job($i) or next;
        if($job->[0] eq $jobname) {
            $self->{cache}->delete('job'.$i);
            return [$i, $job->[1]];
        }
    }
}

sub work {
    my ($self, $tasks, $interval) = @_;
    $interval ||= 5;
    while (1) {
        for my $jobname (keys %$tasks) {
            if (my $job = $self->dequeue($jobname)) {
                infof("Job-ID:%s TaskName:%s", $job->[0], $jobname);
                my $proc = Proc::Simple->new;
                $proc->start($tasks->{$jobname}, $job->[1]);
            }
        }
        sleep($interval);
    }
}

sub flush {
    my $self = shift;
    $self->{cache}->remove('job'.$_) for 1 .. $self->{max_jobs};
    $self->{cache}->remove('index');
    $self->_init_index;
}

1;
__END__

=encoding utf-8

=head1 NAME

JobQueue::SharedMemory - It's new $module

=head1 SYNOPSIS

in your worker,

    ### worker
    
    use JobQueue::SharedMemory;
    our $count = 0;
    
    sub my_incr {
        my $data = shift;
        $count += $data;
    }
    
    sub my_show {
        printf "COUNT = %d\n", $count;
    }
    
    my $q = JobQueue::SharedMemory->new(
        namespace => 'MyQueue',
        max_jobs  => 20,
    );
    my $interval = 3;
    $q->work({
        incr => \&my_incr,
        show => \&my_show,
    }, $interval);

then, in your client,

    ### client
    
    use JobQueue::SharedMemory;
    my $q = JobQueue::SharedMemory->new(
        namespace => 'MyQueue',
        max_jobs  => 20,
    );
    $q->enqueue(incr => int(rand(5) + 1));
    $q->enqueue('show');


=head1 DESCRIPTION

JobQueue::SharedMemory is ...

=head1 LICENSE

Copyright (C) ytnobody.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=cut

