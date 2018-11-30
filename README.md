
xdg_basedir
===========

This is a simple crystal interface to the XDG Base Directories. It is based on
the XDG Base Directory Specification, the latest version of which (0.7) can be
found [here](https://specifications.freedesktop.org/basedir-spec/0.7/).

The XDG Base Directories Specification is a definition of the directories where
things like a program's configuration files and stored data ought to be written
to and read from, along with the order of precedence to be used when searching
for those kinds of files. If you've ever seen a program that stores its
configurations in the `.config` directory, that program is, at least in part,
following this specification.

This crystal interface to the specification provides two low-level methods,
which simply list the base directories of a certain type, as well as a helper
method for easily building file paths relative to them.


installation
------------

First, add the dependency to your project's `shard.yml` file:

```yaml
dependencies:
  xdg_basedir:
    github: shmibs/xdg_basedir
```

and then run `shards install`.


usage
-----

Suppose you're writing a program called `program_name`, and you want to read
one of its configuration files, `file_name.conf`. After reading, you want to
perform some operation on the contents of the file, and then you want to write
the new contents back to `file_name.conf`. Using this module, that might look
something like the following:

```crystal
require "xdg_basedir"

# Note: for simplicity's sake, exception handling has been ignored for the
# calls to File.read and File.write

# files within the XDG Base Directories will typically be further sorted into
# subdirectories, with those subdirectories named for the program or
# application which "owns" them. This is not always the case however, and so it
# isn't enforced
read_path = XDGBasedir.full_path("program_name/file_name.conf", :config, :read)

# the specification dictates that the locations of base directories should be
# determined using both the state of the filesystem and the state of certain
# environment variables. it's thus possible that an appropriate base directory
# won't be found, and so a nil check is required
if read_path
  contents = File.read(read_path)

  # ...do something with the contents here...

  # write_path here is not necessarily the same as read_path above. the above
  # call to full_path will check through a hierarchy of fallback base
  # directories and, if it finds the target file in one of them, will return a
  # path into the directory where it was found. there is only one base
  # directory for writing config files, however, and so it is always returned
  # here. in practice, this means that the first time program_name is run, it
  # might read in some system-wide config file and then write back a
  # user-specific one
  write_path = XDGBasedir.full_path("program_name/file_name.conf", :config,
                                    :write)

  # again, nil check necessary...
  if write_path
    File.write(write_path, contents)
  end
end
```

The `full_path` method takes an argument *type* (set to `:config` in the
example above). This argument indicates that only base directories containing
files of that *type* should be selected. There are four possible types:

- `:data` directories are used for storing and retrieving persistent files
   across multiple runs of a program.
- `:config` directories are used for storing and retrieving a program's
   configuration files.
- `:cache` directories are used for storing non-essential data which may or may
   not be retained
- `:runtime` directories are used for storing runtime files (e.g. lock files or
   sockets)

Every method defined under `XDGBasedir` takes one of these types as an
argument.

In addition to `full_path`, two lower-level methods are also provided:

- `write_dir`, which returns the single directory where files of a given type
  should be written
- `read_dirs`, which returns a hierarchical list of base directories from which
  files of a given type should be read

However, these two methods will probably be less useful.


license
-------

This library is licensed under [The MIT
License](https://opensource.org/licenses/MIT).
