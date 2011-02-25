# $Id: virtualbox_additions_installed.rb 6364 2011-02-18 00:01:37Z benw $

require 'thread'

if FileTest.exists?("/usr/bin/VBoxControl")
  if Facter.value(:kernel) == "Linux"
    ver = ''

    output = %x{/usr/bin/VBoxControl --version}
    ver = output.chomp
    
    Facter.add("virtualbox_additions_installed") do
      confine :kernel => :Linux
      setcode do
        ver
      end
    end
  end
end
