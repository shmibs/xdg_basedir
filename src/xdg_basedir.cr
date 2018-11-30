# This module implements an interface to the XDG Base Directories, compliant
# with version 0.7 of the XDG Base Directory Specification.
#
# Provided are methods for locating XDG Base Directories at runtime, as well as
# a helper method for easily building full file paths relative to them.
#
# Each of the operations below can be performed on one of four categories of
# directories, designated via an argument *type* of value `:data`, `:config`,
# `:cache`, or `:runtime`.
#
# - `:data` directories are used for storing and retrieving persistent files
# across multiple runs of a program.
# - `:config` directories are used for storing and retrieving a program's
# configuration files.
# - `:cache` directories are used for storing non-essential data which may or
# may not be retained
# - `:runtime` directories are used for storing runtime files (e.g. lock files
# or sockets)
#
# For more details, please refer to the specification, which is available
# online [here](https://specifications.freedesktop.org/basedir-spec/0.7/).
module XDGBasedir
  VERSION = "1.0.2"

  # get the base directory into which files of a given *type* should be written
  #
  # Given a *type* of `:data`, `:config`, `:cache`, or `:runtime`, this method
  # returns a single directory into which data of that type should be written,
  # or else `nil`, if no appropriate candidate is found.
  #
  # If a directory is returned, it is guaranteed to always have a terminating
  # '/' character, meaning that, when trying to write a file, it is safe to
  # directly concatenate the directory and the file path that is to be written
  # to within it.
  #
  # ### Example
  #
  #     dir = XDGBasedir.write_dir :config
  #     if dir
  #       File.write "#{dir}created/file.conf", "contents"
  #     end
  #
  def self.write_dir(type = :config) : String?
    case type
    when :data
      if ENV["XDG_DATA_HOME"]? && ENV["XDG_DATA_HOME"] != ""
        s = "#{ENV["XDG_DATA_HOME"]}/"
      else
        if ENV["HOME"]?
          s = "#{ENV["HOME"]}/.local/share/"
        else
          return nil
        end
      end

    when :config
      if ENV["XDG_CONFIG_HOME"]? && ENV["XDG_CONFIG_HOME"] != ""
        s = "#{ENV["XDG_CONFIG_HOME"]}/"
      else
        if ENV["HOME"]?
          s = "#{ENV["HOME"]}/.config/"
        else
          return nil
        end
      end

    when :cache
      if ENV["XDG_CACHE_HOME"]? && ENV["XDG_CACHE_HOME"] != ""
        s = "#{ENV["XDG_CACHE_HOME"]}/"
      else
        if ENV["HOME"]?
          s = "#{ENV["HOME"]}/.cache/"
        else
          return nil
        end
      end

    when :runtime
      if ENV["XDG_RUNTIME_DIR"]? && ENV["XDG_RUNTIME_DIR"] != ""
        s = "#{ENV["XDG_RUNTIME_DIR"]}/"
      else
        # runtime dir has no fallback
        return nil
      end

      # runtime dir must necessarily have certain permissions
      unless File.directory?(s) && File.info(s).permissions.value == 0o0700
        return nil
      end

    else
      raise ArgumentError.new(
        "type must be one of: :data, :config, :cache, :runtime"
      )
    end

    # return result with slashes deduplicated. nil check required because the
    # compiler can't work out that s will have a value here...
    s ? s.gsub(/\/+/, "/") : nil

  end

  # get a list of base directories from which files of a given *type* can be
  # read
  #
  # Given a type of `:data`, `:config`, `:cache`, or `:runtime`, this method
  # returns a string array of directories from which data of that type should
  # be read. If no appropriate candidates are found, it instead returns `nil`.
  #
  # The returned list will be ordered according to precedence. That is, given a
  # returned list `l`, accessing a file should first be attempted from within
  # `l[0]`, if that fails, be attempted from within `l[1]`, and so on.
  #
  # If a directory list is returned, those directories are guaranteed to always
  # have a terminating '/' character, meaning that, when trying to access a
  # file, it is safe to directly concatenate the directory and the file path
  # that is to be accessed within it.
  #
  # ### Example
  #
  #     contents = nil
  #     dir_list = XDGBasedir.read_dirs :config
  #     
  #     if dir_list
  #       dir_list.each { |dir|
  #         if File.file? "#{dir}target/file.conf"
  #           contents = File.read "#{dir}target/file.conf"
  #           break
  #         end
  #       }
  #     end
  #
  def self.read_dirs(type = :config) : Array(String)?
    case type
    when :data
      # first entry is the write dir, if it exists
      if s = self.write_dir(:data)
        l = [s]
      else
        l = [] of String
      end

      if ENV["XDG_DATA_DIRS"]? && !/^:*$/.match(ENV["XDG_DATA_DIRS"])
        ENV["XDG_DATA_DIRS"].split(":").reject{|s| s == ""}.each{|s| l << s}
      else
        l << "/usr/local/share/"
        l << "/usr/share/"
      end

    when :config
      # first entry is the write dir, if it exists
      if s = self.write_dir(:config)
        l = [s]
      else
        l = [] of String
      end

      if ENV["XDG_CONFIG_DIRS"]? && !/^:*$/.match(ENV["XDG_CONFIG_DIRS"])
        ENV["XDG_CONFIG_DIRS"].split(":").reject{|d| d == ""}.each{|s| l << s}
      else
        l << "/etc/xdg/"
      end

    when :cache
      if ENV["XDG_CACHE_HOME"]? && ENV["XDG_CACHE_HOME"] != ""
        l = ["#{ENV["XDG_CACHE_HOME"]}/"]
      else
        if ENV["HOME"]?
          l = ["#{ENV["HOME"]}/.cache/"]
        else
          return nil
        end
      end

    when :runtime
      if ENV["XDG_RUNTIME_DIR"]? && ENV["XDG_RUNTIME_DIR"] != ""
        s = "#{ENV["XDG_RUNTIME_DIR"]}/"
      else
        # runtime dir has no fallback
        return nil
      end

      # runtime dir must necessarily have certain permissions
      unless File.directory?(s) && File.info(s).permissions.value == 0o0700
        return nil
      else
        l = [s]
      end

    else
      raise ArgumentError.new(
        "type must be one of: :data, :config, :cache, :runtime"
      )
    end

    # return result with slashes deduplicated and a trailing slash present.
    l ? l.map { |s| s.gsub(/\/+/, "/").sub(/[^\/]$/, "\\0/") } : nil

  end

  # for a given *relative_path*, get a full file path built against an
  # appropriate base directory
  # 
  # This method takes a *relative_path*, the *type* of that path, and the
  # *action* you intend to perform on it, and returns a full path, constructed
  # by concatenating the *relative_path* to the most appropriate base
  # directory. If an appropriate directory cannot be found, `nil` is returned.
  #
  # The *type* argument indicates what sort of file you intend to access at the
  # full path (`:config`, `:data` ...), and the *action* argument indicates
  # what you intend to to do with it (either `:read` or `:write`). Note that
  # `:write` takes precedence over `:read`, so that if you intend to both read
  # and write, choose `:write`
  #
  # ### Example
  #
  #     data = nil
  #     path = XDGBasedir.full_path "relative/path.dat", :data, :read
  #     
  #     if path
  #       data = File.read path
  #     end
  #
  def self.full_path(relative_path, type = :config,
                     action : Symbol = :read) : String?
    unless action == :read || action == :write
      raise ArgumentError.new(
        "action must be one of: :read, :write"
      )
    end

    case type
    when :data, :config, :cache, :runtime
      if action == :read
        unless l = self.read_dirs(type)
          return nil
        end

        # search the read dirs until relative_path is found
        l.each { |d|
          if File.exists?(d + relative_path)
            return d + relative_path
          end
        }

        # or else just return against the first read dir
        l[0] + relative_path
      else
        d = self.write_dir(type)
        d ? d + relative_path : nil
      end
    else
      raise ArgumentError.new(
        "type must be one of: :data, :config, :cache, :runtime"
      )
    end
  end

  # for a given *relative_path*, get a full file path built against an
  # appropriate base directory
  # 
  # This method takes a *relative_path*, the *type* of that path, and the
  # access *mode* with which that file is to be opened, and returns a full
  # path, constructed by concatenating the *relative_path* to the most
  # appropriate base directory. If an appropriate directory cannot be found,
  # `nil` is returned.
  #
  # The *type* indicates what sort of file you intend to access at the full
  # path (`:config`, `:data` ...), and the *mode* argument is a string, in the
  # common format used by both C's `fopen` and Crystal's `File.open`. For more
  # information, refer to `man fopen` or the Crystal standard library
  # documentation for [File](https://crystal-lang.org/api/latest/File.html).
  #
  # This overloaded version of `full_path` is added for convenience, as, if you
  # intend to call `File.open` on the produced full path, it might be easier to
  # use the same *mode* argument for both methods.
  #
  # ### Example
  #
  #     data = nil
  #     mode = "r"
  #     path = XDGBasedir.full_path "relative/path.dat", :data, mode
  #     
  #     if path
  #       data = File.open(path, mode) do |file|
  #         file.gets_to_end
  #       end
  #     end
  #
  def self.full_path(relative_path, type = :config,
                     mode : String = "r") : String?
    if /^r[^+]*$/.match(mode)
      self.full_path(relative_path, type, :read)
    else
      self.full_path(relative_path, type, :write)
    end
  end

end
