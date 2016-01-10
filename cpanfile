# You can install this projct with curl -L http://cpanmin.us | perl - https://github.com/jhthorsen/mojolicious-plugin-assetpipe/archive/master.tar.gz
requires "Mojolicious" => "6.00";

recommends "CSS::Minifier::XS"        => "0.09";
recommends "JavaScript::Minifier::XS" => "0.11";

test_requires "Test::More" => "0.88";
