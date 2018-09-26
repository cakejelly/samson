# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::PerformanceTracer do
  let(:klass) do
    Class.new do
      extend Samson::PerformanceTracer::Tracers

      def pub_method1
        :pub1
      end

      def pub_method2
        :pub2
      end
    end
  end

  describe '.trace_execution_scoped' do
    let(:custom_tracer) do
      Class.new do
        def self.order
          @order ||= []
        end

        def self.trace_execution_scoped(scope)
          order << scope
          yield
        ensure
          order << :after
        end
      end
    end

    it 'calls all tracers' do
      SamsonDatadogTracer.expects(:enabled?)
      SamsonNewRelic.expects(:tracer_enabled?)
      Samson::PerformanceTracer.trace_execution_scoped('test_scope') { :scoped }.must_equal :scoped
    end

    it "calls tracer in correct order" do
      begin
        Samson::PerformanceTracer.handlers << custom_tracer
        Samson::PerformanceTracer.trace_execution_scoped('test_scope') do
          custom_tracer.order << :inner
          :scoped
        end.must_equal :scoped
        custom_tracer.order.must_equal ['test_scope', :inner, :after]
      ensure
        Samson::PerformanceTracer.handlers.pop
      end
    end
  end

  describe '.add_tracer' do
    it 'add method tracer from performance_tracer hook' do
      performance_tracer_callback = ->(_, _) { true }
      Rails.stubs(:env).returns("staging")
      Samson::Hooks.with_callback(:trace_method, performance_tracer_callback) do
        assert klass.add_tracer(:pub_method1)
        assert klass.add_tracer(:pub_method2)
      end
    end

    it 'raises with invalid arguments' do
      performance_tracer_callback = ->(_) { true }
      assert_raises ArgumentError do
        Samson::Hooks.with_callback(:trace_method, performance_tracer_callback) do
          assert klass.add_tracer(:pub_method1)
        end
      end
    end
  end

  describe '.add_asynchronous_tracer' do
    it 'add asynchronous tracer from asynchronous_performance_tracer hook' do
      methods = [:pub_method1, :pub_method2]
      asyn_tracer_callback = ->(_, _, _) { true }

      Samson::Hooks.with_callback(:asynchronous_performance_tracer, asyn_tracer_callback) do
        assert klass.add_asynchronous_tracer(methods, {})
      end
    end

    it 'raises with invalid arguments' do
      methods = [:pub_method1]
      asyn_tracer_callback = ->(_, _) { true }
      assert_raises ArgumentError do
        Samson::Hooks.with_callback(:asynchronous_performance_tracer, asyn_tracer_callback) do
          assert klass.add_asynchronous_tracer(methods, {})
        end
      end
    end
  end
end
