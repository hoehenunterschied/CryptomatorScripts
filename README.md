# CryptomatorScripts

Two scripts to detect bit rot by generating and checking GnuPG signatures. GnuPG signatures reside in the subdirectory .signatures. The script integritycheck.bash checks the signatures and detects files which are new (have no signature), changed files (signature does not match), deleted files (signature exists, files does not). The second script updatesignatures.bash updates the .signatures subdirectory.

A run of integritycheck.bash should always come first to allow checking if changes to files are up to expectations. If integritycheck.bash reports the expected, run updatesignatures.bash to update the signatures.
