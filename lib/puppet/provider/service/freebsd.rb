Puppet::Type.type(:service).provide :freebsd, :parent => :init do

  desc "Provider for FreeBSD and DragonFly BSD. Uses the `rcvar` argument of init scripts and parses/edits rc files."

  confine :operatingsystem => [:freebsd, :dragonfly]
  defaultfor :operatingsystem => [:freebsd, :dragonfly]

  def rcconf()        '/etc/rc.conf' end
  def rcconf_local()  '/etc/rc.conf.local' end
  def rcconf_dir()    '/etc/rc.conf.d' end

  def self.excludes
    super + ['dhclient', 'power_profile', 'SERVERS', 'FILESYSTEMS', 'NETWORKING', 'LOGIN', 'DAEMON', 'msgs', 'othermta', 'tmp']
  end

  def self.defpath
    superclass.defpath
  end

  def error(msg)
    raise Puppet::Error, msg
  end

  # Parse the "yesno" value. This follows the definition of `checkyesno`
  # in `/etc/rc.subr` for true values, but treats anything not true as
  # false
  def parse_yesno(yesno)
    yesno.sub!(/"(.*)"/, '\1')
    case yesno
    when /^(yes|true|on|1)$/i
      true
    else
      false
    end
  end

  def parse_name(name)
    puts self.initscript
    name.chomp.sub(/^#\s*/, '')
  end

  LINE_REGEX = /^\$?(.+)=(.+)$/

  def parse_rcvars(output)
    lines = output.lines.to_a
    name = parse_name(lines.shift)
    rcvar = nil
    # If no rcvar is found then the service cannot be disabled in
    # rc.conf so set enabled true by default
    enabled = true
    lines.find do |line|
      if not line.start_with?('#') and match = LINE_REGEX.match(line)
        rcvar = match[1]
        enabled = parse_yesno(match[2])
        true
      end
    end
    [name, rcvar, enabled]
  end

  def set_rcvars
    output = execute([self.initscript, :rcvar], :failonfail => true, :combine => false, :squelch => false)
    @rcname, @rcvar, @rcenabled = parse_rcvars(output)
  end

  def rcname
    set_rcvars unless defined?(@rcname)
    @rcname
  end

  def rcvar
    set_rcvars unless defined?(@rcvar)
    @rcvar
  end

  def rcenabled
    set_rcvars unless defined?(@rcenabled)
    @rcenabled
  end

  # Edit rc files and set the service to yes/no
  def rc_edit(yesno)
    debug("Editing rc files: setting #{rcvar} to #{yesno} for #{rcname}")
    rc_add(service, rcvar, yesno) if not self.rc_replace(rcname, rcvar, yesno)
  end

  # Try to find an existing setting in the rc files
  # and replace the value
  def rc_replace(service, rcvar, yesno)
    success = false
    # Replace in all files, not just in the first found with a match
    [rcconf, rcconf_local, rcconf_dir + "/#{service}"].each do |filename|
      if File.exists?(filename)
        s = File.read(filename)
        if s.gsub!(/(#{rcvar}(_enable)?)=\"?(YES|NO)\"?/, "\\1=\"#{yesno}\"")
          File.open(filename, File::WRONLY) { |f| f << s }
          debug("Replaced in #{filename}")
          success = true
        end
      end
    end
    success
  end

  # Add a new setting to the rc files
  def rc_add(service, rcvar, yesno)
    append = "\# Added by Puppet\n#{rcvar}_enable=\"#{yesno}\"\n"
    # First, try the one-file-per-service style
    if File.exists?(rcconf_dir)
      File.open(rcconf_dir + "/#{service}", File::WRONLY | File::APPEND | File::CREAT, 0644) {
        |f| f << append
        self.debug("Appended to #{f.path}")
      }
    else
      # Else, check the local rc file first, but don't create it
      if File.exists?(rcconf_local)
        File.open(rcconf_local, File::WRONLY | File::APPEND) {
          |f| f << append
          self.debug("Appended to #{f.path}")
        }
      else
        # At last use the standard rc.conf file
        File.open(rcconf, File::WRONLY | File::APPEND | File::CREAT, 0644) {
          |f| f << append
          self.debug("Appended to #{f.path}")
        }
      end
    end
  end

  def enabled?
    if rcenabled
      :true
    else
      :false
    end
  end

  def enable
    self.debug("Enabling")
    self.rc_edit("YES")
  end

  def disable
    self.debug("Disabling")
    self.rc_edit("NO")
  end

  def startcmd
    [self.initscript, :onestart]
  end

  def stopcmd
    [self.initscript, :onestop]
  end

  def statuscmd
    [self.initscript, :onestatus]
  end

end
