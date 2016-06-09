Sysmo Core
==========
[![Build Status](https://travis-ci.org/sysmo-nms/sysmo-core.svg?branch=master)](https://travis-ci.org/sysmo-nms/sysmo-core)
[![Appveyor Build Status](https://ci.appveyor.com/api/projects/status/github/sysmo-nms/sysmo-core?branch=master&svg=true)](https://ci.appveyor.com/project/ssbx/sysmo-core)

This is the main repository of sysmo-core, server part of
the [Sysmo NMS](http://www.sysmo.io) monitoring and management solution.

For installation, configuration and development instructions
see the [Wiki](https://github.com/sysmo-nms/sysmo-nms.github.io/wiki).

Dev Mode
========
The common workflow when working on Sysmo-Core, is:

Modify erlang or java code, I actually use IntelliJ for both languages then,

Build a local debug release ("rake rel" is a shortcut to this)
```sh
$ rake debug_release
```

Start the server,
```sh
$ rake run
[...]
```

Or in one pass:
```sh
$ rake rel run
```

Note that:
- The release is located at _build/debug/rel/sysmo/,
- The logs are located at _build/debug/rel/sysmo/log/,
- pping is not setuid so CheckICMP will raize a "permission denied error",

Have fun!

