TmcDecoder
==========

A decoder for traffic information sent via RDS.


TmcReceiver.pl
--------------
This perl script receives data using any serial device to get a data stream from a GNS TMC receiver and decodes TMC messages.
The code can be used under the terms of cc-by-sa-nc 3.0. Note that the full code is in a very early stage of development and might not work as expected.


TmcInterpreter.pm
-----------------
Few functions that read data about Locations and Events from a database file und try do decode the TMC message into an almost human read-able format. 
The actual data files are not included for license reasons.
