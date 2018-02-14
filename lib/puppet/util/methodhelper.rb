# Where we store helper methods related to, um, methods.
module Puppet::Util::MethodHelper
  def requiredopts(*names)
    names.each do |name|
      devfail("#{name} is a required option for #{self.class}") if self.send(name).nil?
    end
  end

  # Iterate over a hash, treating each member as an attribute.
  def set_options(options)
    options.each do |param,value|
      method = param.to_s + "="
      if respond_to? method
        self.send(method, value)
      else
        raise ArgumentError, _("Invalid parameter %{parameter} to object class %{class_name}") % { parameter: param, class_name: self.class }
      end
    end
  end
end
