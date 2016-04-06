# You can install this projct with curl -L http://cpanmin.us | perl - https://github.com/jhthorsen/mojolicious-plugin-assetpack/archive/master.tar.gz
requires "Mojolicious" => "6.00";
requires "IPC::Run3"   => "0.048";

# required in old code
requires "File::Which" => "1.21";

recommends "CSS::Minifier::XS"        => "0.09";
recommends "CSS::Sass"                => "3.3.0";
recommends "Imager::File::PNG"        => "0.90";
recommends "IO::Socket::SSL"          => "1.94";
recommends "JavaScript::Minifier::XS" => "0.11";

test_requires "Test::More" => "0.88";
