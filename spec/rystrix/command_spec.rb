require 'spec_helper'

describe Rystrix::Command do
  describe '#execute' do
    it 'should not block' do
      start = Time.now
      command = Rystrix::Command.new do
        sleep 1
        42
      end
      command.execute
      expect(Time.now - start).to be < 1
    end
  end
end
