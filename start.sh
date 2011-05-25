#!/bin/sh
export PATH="extlib/bin:$PATH";
export PERL5LIB="$PWD/lib:$PWD/extlib/lib/perl5:$PWD/extlib/perl5/x86_64-linux-gnu-thread-multi";
exec perl extlib/bin/start_server --pid-file=$PWD/starman.pid --port=80 -- starman --user www-data --group www-data --workers 10 --timeout 20  script/ambikon_integrationserver.psgi
