# $Id: virtualbox_additions_version.rb 6305 2011-02-08 04:33:02Z $

require 'thread'

if FileTest.exists?("/usr/bin/VBoxControl")
  if Facter.value(:kernel) == "Linux"
    ver = ''

    output = %x{/usr/bin/VBoxControl --version}
    ver = output.chomp
    
    Facter.add("virtualbox_additions_version") do
      confine :kernel => :Linux
      setcode do
        ver
      end
    end
  end
end
