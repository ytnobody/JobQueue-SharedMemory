use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp 'tempdir';
use Guard;
use Proc::Simple;
use JobQueue::SharedMemory;

my $client = JobQueue::SharedMemory->new(namespace => 'Test');
isa_ok $client, 'JobQueue::SharedMemory';

my $cleanup = guard { $client->flush };

my $tempdir = tempdir(CLEANUP => 1);
my $datafile = File::Spec->catfile($tempdir, 'testdata.txt');

my $worker = Proc::Simple->new;
$worker->kill_on_destroy(1);
$worker->start(sub {
    my $q = JobQueue::SharedMemory->new(namespace => 'Test');
    $q->work({
        write => sub { 
            open my $fh, '>>', $datafile;
            print $fh $_[0]."\n";
            close $fh;
        },
    }, 0.1);
});

$client->enqueue(write => 'oreore');
$client->enqueue(write => 'foobar');

sleep 1;

open my $fh, '<', $datafile or die "$datafile - $!";
my $data = join('', (<$fh>));
close $fh;

like $data, qr/^oreore\nfoobar\n/;

done_testing;
