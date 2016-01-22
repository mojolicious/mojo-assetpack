# You can install this projct with curl -L http://cpanmin.us | perl - https://github.com/jhthorsen/mojolicious-plugin-assetpipe/archive/master.tar.gz
requires "Mojolicious" => "6.00";
requires "IPC::Run3"   => "0.048";

recommends "CSS::Minifier::XS"        => "0.09";
recommends "CSS::Sass"                => "0";
recommends "JavaScript::Minifier::XS" => "0.11";

test_requires "Test::More" => "0.88";
