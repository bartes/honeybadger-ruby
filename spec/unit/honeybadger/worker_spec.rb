require 'timecop'
require 'thread'

require 'honeybadger/agent/worker'
require 'honeybadger/config'
require 'honeybadger/backend'
require 'honeybadger/notice'

describe Honeybadger::Agent::Worker do
  let(:instance) { described_class.new(config, feature) }
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, backend: 'null') }
  let(:feature) { :badgers }

  subject { instance }

  after { instance.shutdown! }

  describe "#push" do
    it "flushes payload to backend" do
      payload = double('Badger', id: :foo, to_json: '{}')
      expect(instance.backend).to receive(:notify).with(feature, payload).and_call_original
      instance.push(payload)
      instance.flush
    end
  end

  describe "#initialize" do
    describe "#queue" do
      subject { instance.queue }

      it { should be_a Queue }
    end

    describe "#backend" do
      subject { instance.backend }

      before do
        allow(Honeybadger::Backend::Null).to receive(:new).with(config).and_return(config.backend)
      end

      it { should be_a Honeybadger::Backend::Base }

      it "is initialized from config" do
        should eq config.backend
      end
    end
  end

  describe "#start" do
    it "starts the thread" do
      expect { subject.start }.to change(subject, :thread).to(kind_of(Thread))
    end

    it "changes the pid to the current pid" do
      allow(Process).to receive(:pid).and_return(101)
      expect { subject.start }.to change(subject, :pid).to(101)
    end
  end

  describe "#shutdown" do
    before { subject.start }

    it "stops the thread" do
      expect { subject.shutdown }.to change(subject, :thread).to(nil)
    end

    it "clears the pid" do
      expect { subject.shutdown }.to change(subject, :pid).to(nil)
    end

    context "with an optional timeout" do
      it "kills the thread" do
        # Sleep 1ms to give the thread time to execute the ensure block.
        expect { subject.shutdown(0); sleep(0.001) }.to change(subject, :thread).to(nil)
      end

      it "logs debug info" do
        allow(config.logger).to receive(:debug)
        expect(config.logger).to receive(:debug).with(/kill/i)
        subject.shutdown(0)
      end
    end
  end
end
