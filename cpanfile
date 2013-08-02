requires 'perl', '5.008001';
requires 'Cache::SharedMemoryCache';
requires 'Cache::Isolator';
requires 'Proc::Simple';
requires 'Log::Minimal';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Guard';
    requires 'File::Temp';
};

