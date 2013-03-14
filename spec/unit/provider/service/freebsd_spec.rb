#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:freebsd)

describe Puppet::Type.type(:service).provider(:freebsd) do
  let(:provider) { described_class.new }

  describe "#parse_name" do
    provider.parse_name("# routed : network RIP and router discovery routing daemon\n").should == "routed"
  end

  describe "#parse_var_line" do
    it "parses an unquoted rcvar" do
      provider.parse_var_line('rcvar=dbus_enable').should == 'dbus_enable'
    end

    it "parses a double-quoted rcvar" do
      provider.parse_var_line('rcvar="dbus_enable"').should == 'dbus_enable'
    end

    it "parses a single-quoted rcvar" do
      provider.parse_var_line("rcvar='dbus_enable'").should == 'dbus_enable'
    end
  end

  describe "#parse_yesno" do
    it "interprets 'yes' as true" do
      provider.parse_yesno('yes').should be_true
    end

    it "interprets 'true' as true" do
      provider.parse_yesno('true').should be_true
    end

    it "interprets 'on' as true" do
      provider.parse_yesno('on').should be_true
    end

    it "interprets '1' as true" do
      provider.parse_yesno('1').should be_true
    end

    it "is case insensitive" do
      provider.parse_yesno('YES').should be_true
      provider.parse_yesno('yEs').should be_true
    end

    it "interprets other values as false" do
      provider.parse_yesno('kiuehg').should be_false
      provider.parse_yesno('no').should be_false
      provider.parse_yesno('false').should be_false
      provider.parse_yesno('fALSe').should be_false
      provider.parse_yesno('off').should be_false
      provider.parse_yesno('0').should be_false
    end

    it "ignores double quotes" do
      provider.parse_yesno('"YES"').should be_true
    end
  end

  describe "#parse_rcvars" do
    it "parses the name, rcvar, and status (FreeBSD 7.x, 8.0 format)" do
      rcvar_output = <<OUTPUT
# ntpd
ntpd_enable=YES
OUTPUT
      provider.parse_rcvars(rcvar_output).should == ['ntpd', 'ntpd_enable', true]
    end

    it "parses the name, rcvar, and status (FreeBSD >= 8.1 format)" do
      rcvar_output = <<OUTPUT
# ntpd
#
ntpd_enable="YES"
#   (default: "")
OUTPUT
      provider.parse_rcvars(rcvar_output).should == ['ntpd', 'ntpd_enable', true]
    end

    it "uses the first rcvar given" do
      rcvar_output = <<OUTPUT
# git_daemon
#
git_daemon_enable="NO"
#   (default: "")
a="YES"
#   (default: "")
git=""
#   (default: "")
OUTPUT
      provider.parse_rcvars(rcvar_output).should == ['git_daemon', 'git_daemon_enable', false]
    end

    it "ignores commented lines" do
      rcvar_output = <<OUTPUT
# ntpd
#ntpxd_enable=NO
ntpd_enable=YES
OUTPUT
      provider.parse_rcvars(rcvar_output).should == ['ntpd', 'ntpd_enable', true]
    end

    it "ignores the $ on the rcvar in FreeBSD < 7" do
      rcvar_output = <<OUTPUT
# ntpd
$ntpd_enable=YES
OUTPUT
      provider.parse_rcvars(rcvar_output).should == ['ntpd', 'ntpd_enable', true]
    end

    it "returns true for enabled nil for rcvar if no rcvar line is found" do
      rcvar_output = <<OUTPUT
# dumpon
#

OUTPUT
      provider.parse_rcvars(rcvar_output).should == ['dumpon', nil, true]
    end

    it "should correctly parse rcvar for DragonFly BSD" do
      rcvar_output = <<OUTPUT
# ntpd
$ntpd=YES
OUTPUT
      provider.parse_rcvars(rcvar_output).should == ['ntpd', 'ntpd', true]
    end

    #it "should find the right rcvar_value for FreeBSD < 7" do
    #  @provider.stubs(:rcvar).returns(['# ntpd', 'ntpd_enable=YES'])

    #  @provider.rcvar_value.should == "YES"
    #end

    #it "should find the right rcvar_value for FreeBSD >= 7" do
    #  @provider.stubs(:rcvar).returns(['# ntpd', 'ntpd_enable="YES"', '#   (default: "")'])

    #  @provider.rcvar_value.should == "YES"
    #end
  end
end
