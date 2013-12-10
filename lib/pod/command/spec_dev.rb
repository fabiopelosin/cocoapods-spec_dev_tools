module Pod
  class Command

    #
    #
    class SpecDev < Command
      self.summary = "Tools for spec developers"
      self.abstract_command = true
    end
  end
end

require 'pod/command/spec_dev/derive'
